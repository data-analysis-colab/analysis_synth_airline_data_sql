/*
--------------------------------------------------------------------------------------------
Aircraft Turnaround Time by Capacity and Distance
--------------------------------------------------------------------------------------------
Goal:
    Measure average turnaround times between consecutive flights for each aircraft,
    segmented by seat capacity and route distance.

Methodology:
    1. flight_pairs – Pairs each completed flight (f1) with its next scheduled flight (f2)
       for the same aircraft within a 12-hour window, excluding cases where an
       intervening canceled flight exists.
    2. next_flights – Ranks potential pairings and selects the immediate next flight.
    3. turnaround_indicators – Calculates turnaround times and categorizes aircraft
       by capacity and route distance bands.

Output:
    Provides summary stats (mean, min, max, stddev, quartiles) by seat capacity and
    route distance categories, plus an overall total.
--------------------------------------------------------------------------------------------
This query has been visualized with Seaborn/Matplotlib.
See /visualizations/english/(08)_ac_turnaround_heatmap.png
and /visualizations/german/(08)_bodenzeit_heatmap.png
--------------------------------------------------------------------------------------------
*/

with flight_pairs as (
    select
        f1.flight_number as incoming_flight,
        f1.aircraft_id,
        f1.actual_arrival,
        f1.scheduled_arrival,
        f1.flight_date as arrival_date,
        f1.line_number,
        f2.flight_number as next_flight,
        f2.scheduled_departure,
        f2.actual_departure,
        f2.flight_date as departure_date,
        ac.seat_capacity,
        r.distance_km
    from flights f1
    join flights f2 on f1.aircraft_id = f2.aircraft_id
                    and (f2.scheduled_departure <= f1.actual_arrival + interval '12 hours'
                         and f2.scheduled_departure > f1.actual_arrival) -- future flight
                    and f2.flight_date = f1.flight_date
    join routes r on f1.line_number = r.line_number
    join aircraft ac on f1.aircraft_id = ac.aircraft_id
    where f1.cancelled = false and f2.cancelled = false
          and not exists (select 1 from flights f_cancel
                          where f_cancel.aircraft_id = f1.aircraft_id
                            and f_cancel.cancelled = true
                            and f_cancel.scheduled_departure > f1.actual_arrival
                            and f_cancel.scheduled_departure < f2.scheduled_departure)
),
next_flights as (
    select
        *,
        row_number() over (partition by incoming_flight order by scheduled_departure) as rn
    from flight_pairs
),
turnaround_indicators as (
    select
        case
            when seat_capacity >= 300 then '(5) Seat Capacity >= 300'
            when seat_capacity >= 220 then '(4) Seat Capacity b/w 220 & 299'
            when seat_capacity >= 170 then '(3) Seat Capacity b/w 170 & 219'
            when seat_capacity >= 120 then '(2) Seat Capacity b/w 120 & 169'
            when seat_capacity < 120 then '(1) Seat Capacity < 120'
        end as incoming_flight_seat_capacity,
        case
            when distance_km > 8000 then '(D) Distance > 8000 km'
            when distance_km > 3000 then '(C) Distance b/w 3001 & 8000 km'
            when distance_km between 800 and 3000 then '(B) Distance b/w 800 & 3000 km'
            when distance_km < 800 then '(A) Distance < 800 km'
        end as incoming_flight_distance,
        round(extract(epoch from (scheduled_departure - actual_arrival)) / 60, 2) as turnaround_minutes
    from next_flights
    where rn = 1
)
select
    incoming_flight_seat_capacity,
    incoming_flight_distance,
    count(*) as flight_count,
    round(avg(turnaround_minutes), 2) as avg_turnaround_minutes,
    round(min(turnaround_minutes), 2) as min_turnaround_minutes,
    round(max(turnaround_minutes), 2) as max_turnaround_minutes,
    round(stddev(turnaround_minutes), 2) as turnaround_minutes_stddev,
    percentile_cont(0.25) within group (order by turnaround_minutes) as turnaround_minutes_p25,
    percentile_cont(0.75) within group (order by turnaround_minutes) as turnaround_minutes_p75
from turnaround_indicators
group by incoming_flight_seat_capacity, incoming_flight_distance
union all
select
    'GRAND TOTAL (ALL)',
    'GRAND TOTAL (ALL)',
    count(*),
    round(avg(turnaround_minutes), 2),
    round(min(turnaround_minutes), 2),
    round(max(turnaround_minutes), 2),
    round(stddev(turnaround_minutes), 2),
    percentile_cont(0.25) within group (order by turnaround_minutes),
    percentile_cont(0.75) within group (order by turnaround_minutes)
from turnaround_indicators
group by ()
order by incoming_flight_seat_capacity, incoming_flight_distance;