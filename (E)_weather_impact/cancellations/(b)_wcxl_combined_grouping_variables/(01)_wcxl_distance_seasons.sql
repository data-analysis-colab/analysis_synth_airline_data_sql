/*
-----------------------------------------------------------------------------------------------
Risk Profile: Weather-Related Flight Cancellations by Distance Category and Season
-----------------------------------------------------------------------------------------------
Analyses the frequency of weather-related flight cancellations by distance category
and season (weather_cxl_rate_pct) and assigns cancellation risk levels on that basis.
Also shows the distribution of total weather-related cancellations across distance categories
(weather_cxl_share_pct) and the most impacted airport per combination of distance category
and season.

-----------------------------------------------------------------------------------------------
*/

with seasonal_distance_flights as (
    select
        case
            when extract(month from f.flight_date) in (3, 4, 5) then 'Spring'
            when extract(month from f.flight_date) in (6, 7, 8) then 'Summer'
            when extract(month from f.flight_date) in (9, 10, 11) then 'Autumn'
            when extract(month from f.flight_date) in (12, 1, 2) then 'Winter'
        end as season,
        case
            when r.distance_km < 1500 then 'Short-haul'
            when r.distance_km < 5000 then 'Medium-haul'
            else 'Long-haul'
        end as distance_category,
        f.cancellation_reason,
        ap.airport_code,
        ap.airport_name
    from flights f
    join routes r on f.line_number = r.line_number
    join airports ap on r.departure_airport_code = ap.airport_code
),
seasonal_distance_metrics as (
    select
        season,
        distance_category,
        count(*) as total_flights,
        count(*) filter (where cancellation_reason = 'Weather') as weather_cancellations
    from seasonal_distance_flights
    group by season, distance_category
),

per_airport_metrics as (
    select
        season,
        distance_category,
        count(*) as total_flights,
        count(*) filter (where cancellation_reason = 'Weather') as weather_cancellations,
        airport_code,
        case
            when airport_code = 'GRU' then 'São Paulo International Airport'
            else airport_name
        end as airport_name
    from seasonal_distance_flights
    group by season, distance_category, airport_code, airport_name
),
airports_ranked as (
    select *,
        row_number() over (
             partition by season, distance_category
             order by weather_cancellations * 100.0 / nullif(total_flights, 0) desc
            ) as rn
    from per_airport_metrics
),
most_impacted_airports as (
    select
        concat(distance_category, ' | ', season) as seasonal_distance_category,
        concat(airport_name, ' (', airport_code, ')') as most_impacted_airport
    from airports_ranked
    where rn = 1
),

percentages as (
    select
        concat(distance_category, ' | ', season) as seasonal_distance_category,
        total_flights,
        weather_cancellations,
        round(weather_cancellations * 100 / nullif(sum(weather_cancellations) over (), 0), 2) as weather_cxl_share_pct,
        round(weather_cancellations * 100.0 / nullif(total_flights, 0), 2) as weather_cxl_rate_pct,
        row_number() over (order by weather_cancellations * 100.0 / nullif(total_flights, 0) desc)
            as weather_cxl_rate_rank
    from seasonal_distance_metrics 
)

select
    p.seasonal_distance_category,
    case
        when p.weather_cxl_rate_pct > 5 then 'Very High Risk (Cxl Rate > 5%)'
        when p.weather_cxl_rate_pct > 3 then 'High Risk (Cxl Rate > 3%)'
        when p.weather_cxl_rate_pct > 1 then 'Moderate Risk (Cxl Rate > 1%)'
        when p.weather_cxl_rate_pct > 0 then 'Low Risk (Cxl Rate > 0%)'
        else 'Minimal Risk'
    end as cxl_risk_level,
    mia.most_impacted_airport,
    p.total_flights,
    p.weather_cancellations,
    p.weather_cxl_share_pct,
    p.weather_cxl_rate_pct,
    p.weather_cxl_rate_rank
from percentages p
join most_impacted_airports mia on p.seasonal_distance_category = mia.seasonal_distance_category

union all

select
    'GRAND TOTAL (ALL)',
    case
        when sum(weather_cancellations) * 100.0 / sum(total_flights) > 5 then 'Very High Risk (Cxl Rate > 5%)'
        when sum(weather_cancellations) * 100.0 / sum(total_flights) > 3 then 'High Risk (Cxl Rate > 3%)'
        when sum(weather_cancellations) * 100.0 / sum(total_flights) > 1 then 'Moderate Risk (Cxl Rate > 1%)'
        when sum(weather_cancellations) * 100.0 / sum(total_flights) > 0 then 'Low Risk (Cxl Rate > 0%)'
        else 'Minimal Risk'
    end,
    null,
    sum(total_flights),
    sum(weather_cancellations),
    100.0,
    round(sum(weather_cancellations) * 100.0 / sum(total_flights), 2),
    null
from percentages
group by ()

order by weather_cxl_rate_rank nulls last;