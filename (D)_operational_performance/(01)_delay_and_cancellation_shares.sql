/*
--------------------------------------------------------------------------------------------
Flight Delay and Cancellation Summary
--------------------------------------------------------------------------------------------
Goal:
    Summarize the frequency and magnitude of delays and cancellations by reason.
    Combines departure, arrival, and cancellation statistics in a single unified table
    for quick comparison.

Notes:
    - Delay durations are computed in minutes.
    - "type_share_pct" expresses each reason's share within its delay/cancellation type.
--------------------------------------------------------------------------------------------
*/

select *
from (
    -- your entire UNION ALL query
    select
        '(1) Dep-Delay' as type,
        coalesce(delay_reason_dep, '(ALL DEPARTURE DELAYS)') as reason,
        count(*) as count,
        round(count(*) * 100.0 / sum(count(*)) over(partition by (delay_reason_dep is not null)), 2) as type_share_pct,
        (select count(*) from flights where cancelled = FALSE) as total_flights,
        round(avg(extract(epoch from (actual_departure - scheduled_departure)) / 60), 2) as avg_delay_minutes,
        max(extract(epoch from (actual_departure - scheduled_departure)) / 60) as max_delay_minutes
    from flights
    where delay_reason_dep notnull
    group by cube(delay_reason_dep)

    union all

    select
        '(2) Arr-Delay',
        coalesce(delay_reason_arr, '(ALL ARRIVAL DELAYS)'),
        count(*),
        round(count(*) * 100.0 / sum(count(*)) over(partition by (delay_reason_arr is not null)), 2),
        (select count(*) from flights where cancelled = FALSE),
        round(avg(extract(epoch from (actual_arrival - scheduled_arrival)) / 60), 2),
        max(extract(epoch from (actual_arrival - scheduled_arrival)) / 60)
    from flights
    where delay_reason_arr notnull
    group by cube(delay_reason_arr)

    union all

    select
        '(3) Cancellation',
        coalesce(cancellation_reason, '(ALL CANCELLATIONS)'),
        count(*),
        round(count(*) * 100.0 / sum(count(*)) over(partition by (cancellation_reason is not null)), 2),
        (select count(*) from flights),
        null,
        null
    from flights
    where cancelled = true
    group by cube(cancellation_reason)
) t
order by
    type,
    case when reason ilike '(all%' then 2 else 1 end,
    type_share_pct desc;