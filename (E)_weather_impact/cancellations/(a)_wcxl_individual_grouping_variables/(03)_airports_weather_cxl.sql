/*
--------------------------------------------------------------------------------------------
Risk Profile: Weather-Related Flight Cancellations by Airport
--------------------------------------------------------------------------------------------
Analyses the frequency of weather-related flight cancellations by airport
(weather_cxl_rate_pct) and assigns cancellation risk levels on that basis.
Also shows the distribution of total weather-related cancellations across airports
(weather_cxl_share_pct).

--------------------------------------------------------------------------------------------
*/

with flights_departure_airports as (
    select
        ap.airport_code,
        case
            when ap.airport_code = 'GRU' then 'São Paulo International Airport'
            else ap.airport_name
        end as airport_name,
        ap.climate_region,
        f.cancellation_reason
    from flights f
    join routes r on f.line_number = r.line_number
    join airports ap on r.departure_airport_code = ap.airport_code
),
counts as (
    select
        airport_code,
        min(airport_name) as airport_name,
        min(climate_region) as climate_region,
        count(*) as total_flights,
        count(*) filter (where cancellation_reason = 'Weather') as weather_cancellations
    from flights_departure_airports
    group by airport_code
),
percentages as (
    select
        airport_code,
        airport_name,
        climate_region,
        total_flights,
        weather_cancellations,
        round(weather_cancellations * 100.0 / sum(weather_cancellations) over (), 2) as weather_cxl_share_pct,
        round(weather_cancellations * 100.0 / nullif(total_flights, 0), 2) as weather_cxl_rate_pct,
        row_number() over (order by weather_cancellations * 100.0 / nullif(total_flights, 0) desc)
            as weather_cxl_rate_rank
    from counts
)
select
    case
        when weather_cxl_rate_pct > 5 then 'Very High Risk (Cxl Rate > 5%)'
        when weather_cxl_rate_pct > 3 then 'High Risk (Cxl Rate > 3%)'
        when weather_cxl_rate_pct > 1 then 'Moderate Risk (Cxl Rate > 1%)'
        when weather_cxl_rate_pct > 0 then 'Low Risk (Cxl Rate > 0%)'
        else 'Minimal Risk'
    end as weather_cxl_risk_level,
    airport_code,
    airport_name,
    climate_region,
    total_flights,
    weather_cancellations,
    weather_cxl_share_pct,
    weather_cxl_rate_pct,
    weather_cxl_rate_rank
from percentages
union all
select
    case
        when sum(weather_cancellations) * 100.0 / sum(total_flights) > 5 then 'Very High Risk (Cxl Rate > 5%)'
        when sum(weather_cancellations) * 100.0 / sum(total_flights) > 3 then 'High Risk (Cxl Rate > 3%)'
        when sum(weather_cancellations) * 100.0 / sum(total_flights) > 1 then 'Moderate Risk (Cxl Rate > 1%)'
        when sum(weather_cancellations) * 100.0 / sum(total_flights) > 0 then 'Low Risk (Cxl Rate > 0%)'
        else 'Minimal Risk'
    end,
    'GRAND TOTAL (ALL)',
    'GRAND TOTAL (ALL)',
    'ALL',
    sum(total_flights),
    sum(weather_cancellations),
    100.0,
    round(sum(weather_cancellations) * 100.0 / sum(total_flights), 2),
    Null
from percentages
group by ()
order by weather_cxl_rate_rank nulls last;