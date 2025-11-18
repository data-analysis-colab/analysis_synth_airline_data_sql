/*
--------------------------------------------------------------------------------------------------------
Lost Revenue due to Flight Cancellations
--------------------------------------------------------------------------------------------------------
Purpose:
- Shows how much revenue was lost due to flight cancellations per type of cancellation reason.
--------------------------------------------------------------------------------------------------------
Notes:
- When a flight is canceled, each customer is fully refunded for the ticket price they paid.
- The *total nominal revenue* is the expected revenue in the case that no flights had been canceled.
- The *lost share* is the percentage of *total nominal revenue* that was refunded due to cancellations.
--------------------------------------------------------------------------------------------------------
*/

with year_range as (
    select
        concat(extract(year from min(flight_date)), '-', extract(year from max(flight_date))) as year_range,
        count(distinct flight_number) as total_flights_scheduled,
        sum(price_paid) as tot_nominal_rev
    from bookings
),
cxl_lost_rev as (
    select
        f.flight_number,
        max(yr.year_range) as year_range,
        max(yr.total_flights_scheduled) as tot_flights_scheduled,
        max(yr.tot_nominal_rev) as tot_nominal_rev,
        max(f.cancellation_reason) as cancellation_reason,
        sum(b.price_paid) as lost_rev,
        sum(case when b.class_name = 'Economy' then b.price_paid end) lost_rev_eco,
        sum(case when b.class_name = 'Business' then b.price_paid end) lost_rev_bus,
        sum(case when b.class_name = 'First' then b.price_paid end) lost_rev_first
    from flights f
    join bookings b on f.flight_number = b.flight_number
    cross join year_range yr
    where b.flight_cxl_refund = True
    group by f.flight_number
)
select
    coalesce(cancellation_reason, 'GRAND TOTAL (ALL)') as cancellation_reason,
    max(year_range) as year_range,
    max(tot_flights_scheduled) as tot_flights_scheduled,
    count(cancellation_reason) as cxl_count,
    round(count(cancellation_reason) * 100.0 / max(tot_flights_scheduled), 3)
        as cxl_rate,
    max(tot_nominal_rev) as tot_nominal_rev,
    round(sum(lost_rev) * 100.0 / max(tot_nominal_rev), 3) as lost_share_tot_nom_rev_pct,
    sum(lost_rev) as tot_lost_rev_overall,
    sum(lost_rev_eco) as tot_lost_rev_eco,
    sum(lost_rev_bus) as tot_lost_rev_bus,
    sum(lost_rev_first) as tot_lost_rev_first
from cxl_lost_rev
group by grouping sets (cancellation_reason, ())
order by
    case when cancellation_reason != 'GRAND TOTAL (ALL)' then 1 else 2 end,
    cxl_count desc;