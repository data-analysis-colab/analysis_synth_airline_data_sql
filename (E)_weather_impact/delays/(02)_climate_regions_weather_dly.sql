/*
--------------------------------------------------------------------------------------------
Weather-Related Delays by Climate Region (Departures and Arrivals)
--------------------------------------------------------------------------------------------
Analyses the frequency with which flights departing from or arriving at airports in each
climate region are subject to weather-related delays (delay rate columns). Also shows the
distribution of total weather-related delays across climate regions (delay share columns)
as well as average and maximum delay times in minutes.

--------------------------------------------------------------------------------------------
*/

with flights_climate_regions_dep as (
    select
        extract(epoch from (f.actual_departure - f.scheduled_departure)) / 60 as delay_minutes,
        ap.climate_region as airport_climate_region,
        f.delay_reason_dep
    from flights f
    join routes r on f.line_number = r.line_number
    join airports ap on r.departure_airport_code = ap.airport_code
    where cancelled = FALSE
),
flights_climate_regions_arr as (
    select
        extract(epoch from (f.actual_arrival - f.scheduled_arrival)) / 60 as delay_minutes,
        ap.climate_region as airport_climate_region,
        f.delay_reason_arr
    from flights f
    join routes r on f.line_number = r.line_number
    join airports ap on r.arrival_airport_code = ap.airport_code
    where cancelled = FALSE
),

dep_counts as (
    select
        airport_climate_region,
        count(*) as total_flights,
        count(*) filter (where delay_reason_dep = 'Weather') as dep_weather_delays,
        round(avg(delay_minutes) filter (where delay_reason_dep = 'Weather'), 2) as avg_dep_wx_delay_minutes,
        round(max(delay_minutes) filter (where delay_reason_dep = 'Weather'), 2) as max_dep_wx_delay_minutes
    from flights_climate_regions_dep
    group by airport_climate_region
),
arr_counts as (
    select
        airport_climate_region,
        count(*) as total_flights,
        count(*) filter (where delay_reason_arr = 'Weather') as arr_weather_delays,
        round(avg(delay_minutes) filter (where delay_reason_arr = 'Weather'), 2) as avg_arr_wx_delay_minutes,
        round(max(delay_minutes) filter (where delay_reason_arr = 'Weather'), 2) as max_arr_wx_delay_minutes
    from flights_climate_regions_arr
    group by airport_climate_region
),

dep_percentages as (
    select
        airport_climate_region,
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
        airport_climate_region,
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
        dp.airport_climate_region,
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
            nullif((dp.total_flights + ap.total_flights) / 2, 0), 2) as tot_weather_dly_rate,

        row_number() over (order by (dp.dep_weather_delays + ap.arr_weather_delays) * 100.0 /
            nullif((dp.total_flights + ap.total_flights) / 2, 0) desc) as weather_dly_rate_rank
    from dep_percentages dp
    join arr_percentages ap on dp.airport_climate_region = ap.airport_climate_region
)

select
    airport_climate_region,
    total_flights,
    tot_weather_delays,
    weather_dly_share,
    dep_weather_dly_rate,
    arr_weather_dly_rate,
    tot_weather_dly_rate,
    avg_wx_delay_minutes,
    max_wx_delay_minutes,
    weather_dly_rate_rank
from tot_percentages
union all
select
    'GRAND TOTAL',
    sum(total_flights),
    sum(tot_weather_delays),
    100.0,
    round(sum(dep_weather_delays) * 100.0 / sum(total_flights), 2),
    round(sum(arr_weather_delays) * 100.0 / sum(total_flights), 2),
    round(sum(tot_weather_delays) * 100.0 / sum(total_flights), 2),
    round(sum(tot_weather_delays * avg_wx_delay_minutes) /
          nullif(sum(tot_weather_delays), 0), 2),
    max(max_wx_delay_minutes),
    null
from tot_percentages
group by ()
order by weather_dly_rate_rank nulls last;