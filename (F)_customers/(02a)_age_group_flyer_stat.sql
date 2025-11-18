/*
----------------------------------------------------------------------------------------------------
ANALYSIS: Customer age group vs. frequent flyer status (canonical-age basis)
----------------------------------------------------------------------------------------------------
This query analyzes how unique customers and bookings are distributed across age groups
and frequent flyer statuses, using canonical customer ages (based on each customer's
most recent flight date). It produces both booking-based and customer-based share metrics,
with grouping sets for age groups, flyer statuses, and overall totals.

COLUMN LEGEND (final SELECT output)
----------------------------------------------------------------------------------------------------
age_group:
    - Canonical customer age classification at latest flight date.
    - One of: '(1) Age <= 24', '(2) Age 25-34', '(3) Age 35-44', '(4) Age 45-60', '(5) Age > 60'.
    - Special rows:
        '(ALL)' → subtotal across all statuses for an age group
        '(GRAND TOTAL)' → overall total across all ages and statuses.

frq_flyer_status:
    - Frequent flyer tier label (e.g., '(4) Platinum', '(3) Gold', etc.).
    - Special rows:
        '(ALL STATUSES)' → subtotal across all age groups for a status
        '(GRAND TOTAL)' → overall total across all ages and statuses.

total_bookings_overall:
    - Total number of bookings in the source period (constant across all rows).

total_unique_customers_overall:
    - Total number of distinct customers in the source period (constant across all rows).

age_group_uq_cust_share_overall:
    - Share (%) of unique customers in each age group relative to all customers overall.
    - Only shown for specific age groups (NULL for totals/subtotals).

age_grp_status_bkgs:
    - Total number of bookings for a specific (age group × flyer status) combination.

age_grp_status_bkg_rate:
    - Share (%) of total bookings that fall into each (age group × flyer status) pair.
    - Answers: “What proportion of total bookings come from customers in this age group
      and status?”

age_grp_uq_cust_share_by_status:
    - Share (%) of unique customers within each status that belong to a given age group.
    - Answers: “Within Platinum members, what percentage is aged 25–34?”
    - NULL for subtotal rows where the age group is grouped away.

status_uq_cust_share_by_age_grp:
    - Share (%) of unique customers within each age group that belong to a given status.
    - Answers: “Within customers aged 25–34, what percentage are Platinum members?”
    - NULL for subtotal rows where status is grouped away.

----------------------------------------------------------------------------------------------------
NOTES:
- Canonical age ensures each customer is only counted once, based on their most recent flight.
- Grouping sets create subtotals by age group, by status, and a grand total.
- Distinct customer counts are pre-aggregated to avoid window function limitations.
----------------------------------------------------------------------------------------------------
This query has been visualized with Matplotlib.
See /visualizations/english/(11)_age_frq_flyer_heatmap.png
and /visualizations/german/(11)_alter_vielflieger_heatmap.png
----------------------------------------------------------------------------------------------------
*/

with latest_flights as (
    select
        customer_id,
        max(f.flight_date) as latest_flight_date
    from bookings_2023 b
    join flights f on b.flight_number = f.flight_number
    group by customer_id
),

customer_stats_base as (
    select
        c.customer_id,
        b.frequent_flyer_status_code,
        concat('(', left(b.frequent_flyer_status_code, 1), ') ', fd.frequent_flyer_status) as frq_flyer_status,
        date_part('year', age(l.latest_flight_date, c.date_of_birth))
            + extract(day from age(l.latest_flight_date, c.date_of_birth)) / 365.25 as age
    from bookings_2023 b
    join customers c on b.customer_id = c.customer_id
    join frequent_flyer_discounts fd on b.frequent_flyer_status_code = fd.frequent_flyer_status_code
    join latest_flights l on c.customer_id = l.customer_id
    where c.date_of_birth is not null
),

age_groups as (
    select
        case
            when age <= 24 then '(1) Age <= 24'
            when age <= 34 then '(2) Age 25-34'
            when age <= 44 then '(3) Age 35-44'
            when age <= 60 then '(4) Age 45-60'
            when age > 60 then '(5) Age > 60'
            else 'Unknown'
        end as age_group,
        *
    from customer_stats_base
),

total_unique_customers as (
    select count(distinct customer_id) as total_uq_cust_overall
    from age_groups
),
unique_customers_per_status as (
    select
        frequent_flyer_status_code,
        count(distinct customer_id) as tot_uq_cust_status
    from age_groups
    group by frequent_flyer_status_code
),
unique_customers_per_age_group as (
    select
        age_group,
        count(distinct customer_id) as tot_uq_cust_age_group,
        round(count(distinct customer_id) * 100.0 /
            nullif((select total_uq_cust_overall from total_unique_customers), 0), 2)
            as age_group_uq_cust_share_overall
    from age_groups
    group by age_group
),

customer_stats as (
    select
        ag.*,
        ucs.tot_uq_cust_status,
        usg.tot_uq_cust_age_group,
        usg.age_group_uq_cust_share_overall,
        tuc.total_uq_cust_overall,
        count(*) over () as total_bkgs_overall
    from age_groups ag
    join unique_customers_per_status ucs on ag.frequent_flyer_status_code = ucs.frequent_flyer_status_code
    join unique_customers_per_age_group usg on ag.age_group = usg.age_group
    cross join total_unique_customers tuc
)

select
    case
        when grouping(age_group) = 1 and grouping(frq_flyer_status) = 1 then '(GRAND TOTAL)'
        when grouping(age_group) = 1 then '(ALL)'
        else age_group
    end as age_group,
    case
        when grouping(frq_flyer_status) = 1 and grouping(age_group) = 1 then '(GRAND TOTAL)'
        when grouping(frq_flyer_status) = 1 then '(ALL STATUSES)'
        else frq_flyer_status
    end as frq_flyer_status,

    max(total_bkgs_overall) as total_bookings_overall,
    max(total_uq_cust_overall) as total_unique_customers_overall,
    case
        when grouping(age_group) = 1 and grouping(frq_flyer_status) = 1
              -- grand total 100 underlines the percentage character of the column
            then round(count(distinct customer_id) * 100.0 / nullif(max(total_uq_cust_overall), 0), 2)
        when grouping(age_group) = 1 then null   -- no age group share when age is grouped away
        else max(age_group_uq_cust_share_overall)
    end as age_group_uq_cust_share_overall,

    count(*) as age_grp_status_bkgs,
    round(count(*) * 100.0 / nullif(max(total_bkgs_overall), 0), 2) as age_grp_status_bkg_rate,

    case
        when grouping(age_group) = 1 and grouping(frq_flyer_status) = 1
            then round(count(distinct customer_id) * 100.0 / nullif(max(total_uq_cust_overall), 0), 2)
        when grouping(age_group) = 1 then null
        else round(count(distinct customer_id) * 100.0 / nullif(max(tot_uq_cust_age_group), 0), 2)
    end as age_grp_uq_cust_share_by_status,

    case
        when grouping(frq_flyer_status) = 1 and grouping(age_group) = 1
            then round(count(distinct customer_id) * 100.0 / nullif(max(total_uq_cust_overall), 0), 2)
        when grouping(frq_flyer_status) = 1 then null
        else round(count(distinct customer_id) * 100.0 / nullif(max(tot_uq_cust_status), 0), 2)
    end as status_uq_cust_share_by_age_grp
from customer_stats
group by grouping sets ((age_group, frq_flyer_status), age_group, frq_flyer_status, ())
order by age_group, frq_flyer_status;