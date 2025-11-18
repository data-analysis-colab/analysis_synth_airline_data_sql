/*
--------------------------------------------------------------------------------------------
Risk Profile: Weather-Related Flight Cancellations by Season
--------------------------------------------------------------------------------------------
Analyses the frequency of weather-related flight cancellations by season
(weather_cxl_rate_pct) and assigns cancellation risk levels on that basis.
Also shows the distribution of total weather-related cancellations across seasons
(weather_cxl_share_pct).

--------------------------------------------------------------------------------------------
*/

with seasonal_flights as (
    select
        case
            when extract(month from flight_date) in (3, 4, 5) then '(1) Spring'
            when extract(month from flight_date) in (6, 7, 8) then '(2) Summer'
            when extract(month from flight_date) in (9, 10, 11) then '(3) Autumn'
            when extract(month from flight_date) in (12, 1, 2) then '(4) Winter'
        end as season,
        cancellation_reason
    from flights
),
counts as (
    select
        season,
        count(*) as total_flights,
        count(*) filter (where cancellation_reason = 'Weather') as weather_cancellations
    from seasonal_flights
    group by season
),
percentages as (
    select
        season,
        total_flights,
        weather_cancellations,
        round(weather_cancellations * 100 / sum(weather_cancellations) over (), 2) as weather_cxl_share_pct,
        round(weather_cancellations * 100.0 / nullif(total_flights, 0), 2) as weather_cxl_rate_pct
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
order by season;