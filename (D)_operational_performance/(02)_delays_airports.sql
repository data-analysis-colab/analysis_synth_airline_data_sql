/*
--------------------------------------------------------------------------------------------
Top Airports by Delay Rate and Reason (Departure vs. Arrival)
--------------------------------------------------------------------------------------------
Goal:
    Identify airports most affected by specific delay reasons, considering both
    departure and arrival phases.

Structure:
    - The query builds separate departure and arrival delay summaries, each including
        * Delay counts, average/max duration, and two key percentages:
            - <delay_reason>_share_pct: share of all delays for that reason.
            - <delay_rate_pct>: share of total flights at that airport.
        * Rankings (top 2 per delay reason) plus total lines per reason group.

Interpretation:
    - Each phase (departure, arrival) is presented separately.
    - “TOTAL (ALL IN REASON GRP)” rows show group-wide aggregates for context.
--------------------------------------------------------------------------------------------
*/

with flights_departure_airports as (
    select
        extract(epoch from (f.actual_departure - f.scheduled_departure)) / 60 as delay_minutes,
        ap.airport_code,
        case
            when ap.airport_code = 'GRU' then 'São Paulo International Airport'
            else ap.airport_name
        end as airport_name,
        ap.climate_region,
        f.delay_reason_dep,
        f.cancelled
    from flights f
    join routes r on f.line_number = r.line_number
    join airports ap on r.departure_airport_code = ap.airport_code
    where cancelled = FALSE
),
flights_arrival_airports as (
    select
        extract(epoch from (f.actual_arrival - f.scheduled_arrival)) / 60 as delay_minutes,
        ap.airport_code,
        case
            when ap.airport_code = 'GRU' then 'São Paulo International Airport'
            else ap.airport_name
        end as airport_name,
        ap.climate_region,
        f.delay_reason_arr,
        f.cancelled
    from flights f
    join routes r on f.line_number = r.line_number
    join airports ap on r.arrival_airport_code = ap.airport_code
    where cancelled = FALSE
),

tot_flights_dep_airports as (
    select airport_code, count(*) as total_flights from flights_departure_airports
    where cancelled = FALSE group by airport_code
),
dep_counts as (
    select
        delay_reason_dep,
        airport_code,
        min(airport_name) as airport_name,
        min(climate_region) as climate_region,
        count(*) as departure_delays,
        round(avg(delay_minutes), 2) as avg_dep_delay_minutes,
        round(max(delay_minutes), 2) as max_dep_delay_minutes
    from flights_departure_airports
    where delay_reason_dep is not null
    group by delay_reason_dep, airport_code
),
tot_flights_arr_airports as (
    select airport_code, count(*) as total_flights from flights_arrival_airports
    where cancelled = FALSE group by airport_code
),
arr_counts as (
    select
        delay_reason_arr,
        airport_code,
        min(airport_name) as airport_name,
        min(climate_region) as climate_region,
        count(*) as arrival_delays,
        round(avg(delay_minutes), 2) as avg_arr_delay_minutes,
        round(max(delay_minutes), 2) as max_arr_delay_minutes
    from flights_arrival_airports
    where delay_reason_arr is not null
    group by delay_reason_arr, airport_code
),

dep_percentages as (
    select
        dc.delay_reason_dep,
        dc.airport_code,
        dc.airport_name,
        dc.climate_region,
        tfd.total_flights,
        dc.departure_delays,
        dc.avg_dep_delay_minutes,
        dc.max_dep_delay_minutes,
        round(dc.departure_delays * 100.0 / sum(dc.departure_delays) over (partition by dc.delay_reason_dep), 2)
            as dep_delay_reason_share,
        round(dc.departure_delays * 100.0 / nullif(tfd.total_flights, 0), 2) as dep_delay_rate,
        row_number() over (partition by dc.delay_reason_dep
            order by dc.departure_delays * 100.0 / nullif(tfd.total_flights, 0) desc)
            as dep_dly_rate_rank
    from dep_counts dc
    join tot_flights_dep_airports tfd on dc.airport_code = tfd.airport_code
),
arr_percentages as (
    select
        ac.delay_reason_arr,
        ac.airport_code,
        ac.airport_name,
        ac.climate_region,
        tfa.total_flights,
        ac.arrival_delays,
        ac.avg_arr_delay_minutes,
        ac.max_arr_delay_minutes,
        round(ac.arrival_delays * 100.0 / sum(ac.arrival_delays) over (partition by ac.delay_reason_arr), 2)
            as arr_delay_reason_share,
        round(ac.arrival_delays * 100.0 / nullif(tfa.total_flights, 0), 2) as arr_delay_rate,
        row_number() over (partition by ac.delay_reason_arr
            order by ac.arrival_delays * 100.0 / nullif(tfa.total_flights, 0) desc)
            as arr_dly_rate_rank
    from arr_counts ac
    join tot_flights_arr_airports tfa on ac.airport_code = tfa.airport_code
)

select
    '(1) Departure' as phase,
    delay_reason_dep as delay_reason,
    concat('Dly Rate Rank: ', dep_dly_rate_rank, ' | ', airport_code) as ranked_airport_code,
    airport_name,
    climate_region,
    total_flights,
    departure_delays as delay_count,
    dep_delay_reason_share as delay_reason_grp_share_pct,
    dep_delay_rate as airport_delay_rate_pct,
    avg_dep_delay_minutes as avg_delay_minutes,
    max_dep_delay_minutes as max_delay_minutes
from dep_percentages
where dep_dly_rate_rank <= 2

union all

select
    '(2) Arrival',
    delay_reason_arr,
    concat('Dly Rate Rank: ', arr_dly_rate_rank, ' | ', airport_code),
    airport_name,
    climate_region,
    total_flights,
    arrival_delays,
    arr_delay_reason_share,
    arr_delay_rate,
    avg_arr_delay_minutes,
    max_arr_delay_minutes
from arr_percentages
where arr_dly_rate_rank <= 2

union all

select
    '(1) Departure',
    delay_reason_dep,
    'TOTAL (ALL IN REASON GRP)',
    '(ALL)',
    null,
    sum(total_flights),
    sum(departure_delays),
    100.0,
    round(sum(departure_delays) * 100.0 / nullif(sum(total_flights), 0), 2),
    round(sum(departure_delays * avg_dep_delay_minutes) / nullif(sum(departure_delays), 0), 2),
    max(max_dep_delay_minutes)
from dep_percentages
group by delay_reason_dep

union all

select
    '(2) Arrival',
    delay_reason_arr,
    'TOTAL (ALL IN REASON GRP)',
    '(ALL)',
    null,
    sum(total_flights),
    sum(arrival_delays),
    100.0,
    round(sum(arrival_delays) * 100.0 / nullif(sum(total_flights), 0), 2),
    round(sum(arrival_delays * avg_arr_delay_minutes) / nullif(sum(arrival_delays), 0), 2),
    max(max_arr_delay_minutes)
from arr_percentages
group by delay_reason_arr

order by phase, delay_reason, ranked_airport_code;