/*
--------------------------------------------------------------------------------------------
Risk Profile: Weather-Related Flight Cancellations by Distance Category
--------------------------------------------------------------------------------------------
Analyses the frequency of weather-related flight cancellations by flight distance
category (weather_cxl_rate_pct) and assigns cancellation risk levels on that basis.
Also shows the distribution of total weather-related cancellations across distance
categories (weather_cxl_share_pct).

--------------------------------------------------------------------------------------------
*/

with categorized_flights as (
    select
        case
            when distance_km < 1500 then '(1) Short-haul'
            when distance_km < 5000 then '(2) Medium-haul'
            else '(3) Long-haul'
        end as distance_category,
        f.cancellation_reason
    from flights f
    join routes r on f.line_number = r.line_number
),
counts as (
    select
        distance_category,
        count(*) as total_flights,
        count(*) filter (where cancellation_reason = 'Weather') as weather_cancellations
    from categorized_flights
    group by distance_category
),
percentages as (
    select
        distance_category,
        total_flights,
        weather_cancellations,
        round(weather_cancellations * 100.0 / sum(weather_cancellations) over (), 2) as weather_cxl_share_pct,
        round(weather_cancellations * 100.0 / total_flights, 2) as weather_cxl_rate_pct
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
    round(sum(weather_cancellations) * 100.0 / sum(total_flights), 2)
from percentages
group by ()
order by distance_category;