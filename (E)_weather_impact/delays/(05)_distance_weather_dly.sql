/*
--------------------------------------------------------------------------------------------
Weather-Related Delays by Distance Category (Departures and Arrivals)
--------------------------------------------------------------------------------------------
Analyses the frequency with which flights falling into a certain distance category
are subject to weather-related delays during departure or arrival (delay rate columns).
Also shows the distribution of total weather-related delays across distance categories
(delay share columns) as well as average and maximum delay times in minutes.

Distance Categories:
    - (1) Short-haul: < 1500 km
    - (2) Medium-haul: between 1500 and 5000 km
    - (3) Long-haul: over 5000 km
--------------------------------------------------------------------------------------------
*/

with flights_distance_dep as (
    select
        extract(epoch from (f.actual_departure - f.scheduled_departure)) / 60 as delay_minutes,
        case
            when distance_km < 1500 then '(1) Short-haul'
            when distance_km < 5000 then '(2) Medium-haul'
            else '(3) Long-haul'
        end as distance_category,
        f.delay_reason_dep
    from flights f
    join routes r on f.line_number = r.line_number
    join airports ap on r.departure_airport_code = ap.airport_code
    where cancelled = FALSE
),
flights_distance_arr as (
    select
        extract(epoch from (f.actual_arrival - f.scheduled_arrival)) / 60 as delay_minutes,
        case
            when distance_km < 1500 then '(1) Short-haul'
            when distance_km < 5000 then '(2) Medium-haul'
            else '(3) Long-haul'
        end as distance_category,
        f.delay_reason_arr
    from flights f
    join routes r on f.line_number = r.line_number
    join airports ap on r.arrival_airport_code = ap.airport_code
    where cancelled = FALSE
),

dep_counts as (
    select
        distance_category,
        count(*) as total_flights,
        count(*) filter (where delay_reason_dep = 'Weather') as dep_weather_delays,
        round(avg(delay_minutes) filter (where delay_reason_dep = 'Weather'), 2) as avg_dep_wx_delay_minutes,
        round(max(delay_minutes) filter (where delay_reason_dep = 'Weather'), 2) as max_dep_wx_delay_minutes
    from flights_distance_dep
    group by distance_category
),
arr_counts as (
    select
        distance_category,
        count(*) as total_flights,
        count(*) filter (where delay_reason_arr = 'Weather') as arr_weather_delays,
        round(avg(delay_minutes) filter (where delay_reason_arr = 'Weather'), 2) as avg_arr_wx_delay_minutes,
        round(max(delay_minutes) filter (where delay_reason_arr = 'Weather'), 2) as max_arr_wx_delay_minutes
    from flights_distance_arr
    group by distance_category
),

dep_percentages as (
    select
        distance_category,
        total_flights,
        dep_weather_delays,
        avg_dep_wx_delay_minutes,
        max_dep_wx_delay_minutes,
        round(dep_weather_delays * 100 / sum(dep_weather_delays) over (), 2) as dep_weather_dly_share,
        round(dep_weather_delays * 100.0 / nullif(total_flights, 0), 2) as dep_weather_dly_rate
    from dep_counts
),
arr_percentages as (
    select
        distance_category,
        total_flights,
        arr_weather_delays,
        avg_arr_wx_delay_minutes,
        max_arr_wx_delay_minutes,
        round(arr_weather_delays * 100 / sum(arr_weather_delays) over (), 2) as arr_weather_dly_share,
        round(arr_weather_delays * 100.0 / nullif(total_flights, 0), 2) as arr_weather_dly_rate
    from arr_counts
),
tot_percentages as (
    select
        dp.distance_category,
        (dp.total_flights + ap.total_flights) / 2 as total_flights,

        dp.dep_weather_delays,
        ap.arr_weather_delays,
        dp.dep_weather_delays + ap.arr_weather_delays as tot_weather_delays,

        round((dp.avg_dep_wx_delay_minutes * dp.dep_weather_delays +
               ap.avg_arr_wx_delay_minutes * ap.arr_weather_delays) /
              nullif((dp.dep_weather_delays + ap.arr_weather_delays), 0), 2) as avg_wx_delay_minutes,
        greatest(dp.max_dep_wx_delay_minutes, ap.max_arr_wx_delay_minutes) as max_wx_delay_minutes,

        dp.dep_weather_dly_share,
        ap.arr_weather_dly_share,
        round((dp.dep_weather_delays + ap.arr_weather_delays) * 100.0 /
            sum(dp.dep_weather_delays + ap.arr_weather_delays) over (), 2) as weather_dly_share,

        dp.dep_weather_dly_rate,
        ap.arr_weather_dly_rate,
        round((dp.dep_weather_delays + ap.arr_weather_delays) * 100.0 /
            nullif((dp.total_flights + ap.total_flights) / 2, 0), 2) as tot_weather_dly_rate

    from dep_percentages dp
    join arr_percentages ap on dp.distance_category = ap.distance_category
)

select
    distance_category,
    total_flights,
    tot_weather_delays,
    weather_dly_share,
    dep_weather_dly_rate,
    arr_weather_dly_rate,
    tot_weather_dly_rate,
    avg_wx_delay_minutes,
    max_wx_delay_minutes
from tot_percentages
union all
select
    'GRAND TOTAL (ALL)',
    sum(total_flights),
    sum(tot_weather_delays),
    100.0,
    round(sum(dep_weather_delays) * 100.0 / sum(total_flights), 2),
    round(sum(arr_weather_delays) * 100.0 / sum(total_flights), 2),
    round(sum(tot_weather_delays) * 100.0 / sum(total_flights), 2),
    round(sum(tot_weather_delays * avg_wx_delay_minutes) /
          nullif(sum(tot_weather_delays), 0), 2),
    max(max_wx_delay_minutes)
from tot_percentages
group by ()
order by distance_category nulls last;