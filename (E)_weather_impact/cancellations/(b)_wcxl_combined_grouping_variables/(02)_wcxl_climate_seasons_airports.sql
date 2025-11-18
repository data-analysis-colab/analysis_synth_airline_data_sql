/*
----------------------------------------------------------------------------------------------------
Risk Profile: Weather-Related Flight Cancellations by Climate Region and Season
----------------------------------------------------------------------------------------------------

Analyses the frequency of weather-related flight cancellations by climate region
and season (weather_cxl_rate_pct) and assigns cancellation risk levels on that basis.
Also shows the distribution of total weather-related cancellations across climate regions
(weather_cxl_share_pct) and the most impacted airport per combination of season and region.

----------------------------------------------------------------------------------------------------
This query has been visualized with Seaborn/Matplotlib.
See /visualizations/english/(09)_wcxl_climate_seasons_airports.png
and /visualizations/german/(09)_wcxl_klima_jahreszeit_flughafen.png
----------------------------------------------------------------------------------------------------
*/

with seasonal_climate_flights as (
    select
        case
            when extract(month from f.flight_date) in (3, 4, 5) then 'Spring'
            when extract(month from f.flight_date) in (6, 7, 8) then 'Summer'
            when extract(month from f.flight_date) in (9, 10, 11) then 'Autumn'
            when extract(month from f.flight_date) in (12, 1, 2) then 'Winter'
        end as season,
        ap.climate_region as airport_climate_region,
        f.cancellation_reason,
        ap.airport_code,
        ap.airport_name
    from flights f
    join routes r on f.line_number = r.line_number
    join airports ap on r.departure_airport_code = ap.airport_code
),
seasonal_climate_metrics as (
    select
        season,
        airport_climate_region,
        count(*) as total_flights,
        count(*) filter (where cancellation_reason = 'Weather') as weather_cancellations
    from seasonal_climate_flights
    group by season, airport_climate_region
),

per_airport_metrics as (
    select
        season,
        airport_climate_region,
        count(*) as total_flights,
        count(*) filter (where cancellation_reason = 'Weather') as weather_cancellations,
        airport_code,
        case
            when airport_code = 'GRU' then 'São Paulo International Airport'
            else airport_name
        end as airport_name
    from seasonal_climate_flights
    group by season, airport_climate_region, airport_code, airport_name
),
airports_ranked as (
    select *,
        row_number() over (
             partition by season, airport_climate_region
             order by weather_cancellations * 100.0 / nullif(total_flights, 0) desc
            ) as rn
    from per_airport_metrics
),
most_impacted_airports as (
    select
        concat(season, ' | ', airport_climate_region, ' Region') as seasonal_airport_climate_region,
        concat(airport_name, ' (', airport_code, ')') as most_impacted_airport
    from airports_ranked
    where rn = 1
),
percentages as (
    select
        concat(season, ' | ', airport_climate_region, ' Region') as seasonal_airport_climate_region,
        total_flights,
        weather_cancellations,
        round(weather_cancellations * 100 / nullif(sum(weather_cancellations) over (), 0), 2) as weather_cxl_share_pct,
        round(weather_cancellations * 100.0 / nullif(total_flights, 0), 2) as weather_cxl_rate_pct,
        row_number() over (order by weather_cancellations * 100.0 / nullif(total_flights, 0) desc)
            as weather_cxl_rate_rank
    from seasonal_climate_metrics
)

select
    p.seasonal_airport_climate_region,
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
join most_impacted_airports mia on p.seasonal_airport_climate_region = mia.seasonal_airport_climate_region

union all

select
    'GRAND TOTAL',
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
    round(sum(weather_cancellations) * 100.0 / nullif(sum(total_flights), 0), 2),
    null
from percentages
group by ()
order by weather_cxl_rate_rank nulls last;



-- create a view with minor modifications for visualization
create or replace view wcxl_climate_seasons_airports as
with seasonal_climate_flights as (
    select
        case
            when extract(month from f.flight_date) in (3, 4, 5) then 'Spring'
            when extract(month from f.flight_date) in (6, 7, 8) then 'Summer'
            when extract(month from f.flight_date) in (9, 10, 11) then 'Autumn'
            when extract(month from f.flight_date) in (12, 1, 2) then 'Winter'
        end as season,
        ap.climate_region as airport_climate_region,
        f.cancellation_reason,
        ap.airport_code,
        ap.airport_name
    from flights f
    join routes r on f.line_number = r.line_number
    join airports ap on r.departure_airport_code = ap.airport_code
),
seasonal_climate_metrics as (
    select
        season,
        airport_climate_region,
        count(*) as total_flights,
        count(*) filter (where cancellation_reason = 'Weather') as weather_cancellations
    from seasonal_climate_flights
    group by season, airport_climate_region
),
per_airport_metrics as (
    select
        season,
        airport_climate_region,
        count(*) as total_flights,
        count(*) filter (where cancellation_reason = 'Weather') as weather_cancellations,
        airport_code,
        case
            when airport_code = 'GRU' then 'São Paulo International Airport'
            else airport_name
        end as airport_name
    from seasonal_climate_flights
    group by season, airport_climate_region, airport_code, airport_name
),
airports_ranked as (
    select *,
        row_number() over (
             partition by season, airport_climate_region
             order by weather_cancellations * 100.0 / nullif(total_flights, 0) desc
            ) as rn
    from per_airport_metrics
),
most_impacted_airports as (
    select
        concat(season, ' | ', airport_climate_region, ' Region') as seasonal_airport_climate_region,
        concat(airport_name, ' (', airport_code, ')') as most_impacted_airport
    from airports_ranked
    where rn = 1
),
percentages as (
    select
        concat(season, ' | ', airport_climate_region, ' Region') as seasonal_airport_climate_region,
        season,
        airport_climate_region,
        total_flights,
        weather_cancellations,
        round(weather_cancellations * 100 / nullif(sum(weather_cancellations) over (), 0), 2) as weather_cxl_share_pct,
        round(weather_cancellations * 100.0 / nullif(total_flights, 0), 2) as weather_cxl_rate_pct,
        row_number() over (order by weather_cancellations * 100.0 / nullif(total_flights, 0) desc)
            as weather_cxl_rate_rank
    from seasonal_climate_metrics
)

select
    p.seasonal_airport_climate_region,
    p.season,
    p.airport_climate_region,
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
    p.weather_cxl_rate_pct
from percentages p
join most_impacted_airports mia on p.seasonal_airport_climate_region = mia.seasonal_airport_climate_region
where p.weather_cxl_rate_pct > 0
order by p.weather_cxl_rate_pct desc;