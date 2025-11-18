/*
--------------------------------------------------------------------------------------------
Risk Profile: Weather-Related Flight Cancellations by Climate Region
--------------------------------------------------------------------------------------------
Analyses the frequency of weather-related flight cancellations by climate region
(weather_cxl_rate_pct) and assigns cancellation risk levels on that basis.
Also shows the distribution of total weather-related cancellations across climate regions
(weather_cxl_share_pct).

--------------------------------------------------------------------------------------------
*/

with flights_climate_regions as (
    select
        ap.climate_region as airport_climate_region,
        f.cancellation_reason
    from flights f
    join routes r on f.line_number = r.line_number
    join airports ap on r.departure_airport_code = ap.airport_code
),
counts as (
    select
        airport_climate_region,
        count(*) as total_flights,
        count(*) filter (where cancellation_reason = 'Weather') as weather_cancellations
    from flights_climate_regions
    group by airport_climate_region
),
percentages as (
    select
        airport_climate_region,
        total_flights,
        weather_cancellations,
        round(weather_cancellations * 100 / sum(weather_cancellations) over (), 2) as weather_cxl_share_pct,
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
    end as cxl_risk_level,
    *
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
    sum(total_flights),
    sum(weather_cancellations),
    100.0,
    round(sum(weather_cancellations) * 100.0 / sum(total_flights), 2),
    Null
from percentages
group by ()
order by weather_cxl_rate_rank nulls last;