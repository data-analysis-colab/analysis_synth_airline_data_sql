/*
----------------------------------------------------------------------------------------------------
ANALYSIS: Customer gender vs. frequent flyer status (canonical-age basis)
----------------------------------------------------------------------------------------------------
This query analyzes how unique customers and bookings are distributed across genders
and frequent flyer statuses. It produces both booking-based and customer-based share metrics,
with grouping sets for gender, flyer statuses, and overall totals.

COLUMN LEGEND (final SELECT output)
----------------------------------------------------------------------------------------------------
gender:
    - Customer gender
    - Special rows:
        '(ALL)' → subtotal across all statuses for a gender group
        '(GRAND TOTAL)' → overall total across all genders and statuses.

frq_flyer_status:
    - Frequent flyer tier label (e.g., '(4) Platinum', '(3) Gold', etc.).
    - Special rows:
        '(ALL STATUSES)' → subtotal across all genders for a status
        '(GRAND TOTAL)' → overall total across all genders and statuses.

total_bookings_overall:
    - Total number of bookings in the source period (constant across all rows).

total_unique_customers_overall:
    - Total number of distinct customers in the source period (constant across all rows).

gender_uq_cust_share_overall:
    - Share (%) of unique customers per gender relative to all customers overall.
    - Only shown where gender is not grouped away (NULL for totals/subtotals).

gender_status_bkgs:
    - Total number of bookings for a specific (gender × flyer status) combination.

gender_status_bkg_rate:
    - Share (%) of total bookings that fall into each (gender × flyer status) pair.
    - Answers: “What proportion of total bookings come from female customers with Silver
      status?”

gender_uq_cust_share_by_status:
    - Share (%) of unique customers within each status that belong to a given gender.
    - Answers: “Within Platinum members, what percentage of customers is male?”
    - NULL for subtotal rows where gender is grouped away.

status_uq_cust_share_by_gender:
    - Share (%) of unique customers within each gender group that belong to a given status.
    - Answers: “Within male customers, what percentage are Platinum members?”
    - NULL for subtotal rows where status is grouped away.

----------------------------------------------------------------------------------------------------
NOTES:
- Grouping sets create subtotals by gender, by status, and a grand total.
- Distinct customer counts are pre-aggregated to avoid window function limitations.
----------------------------------------------------------------------------------------------------
*/

with customer_stats_base as (
    select
        c.customer_id,
        b.frequent_flyer_status_code,
        case when c.gender = 'female' then '(1) Female' else '(2) Male' end as gender,
        concat('(', left(b.frequent_flyer_status_code, 1), ') ', fd.frequent_flyer_status) as frq_flyer_status
    from bookings_2023 b
    join customers c on b.customer_id = c.customer_id
    join frequent_flyer_discounts fd on b.frequent_flyer_status_code = fd.frequent_flyer_status_code
),

total_unique_customers as (
    select count(distinct customer_id) as total_uq_cust_overall
    from customer_stats_base
),
unique_customers_per_status as (
    select
        frequent_flyer_status_code,
        count(distinct customer_id) as tot_uq_cust_status
    from customer_stats_base
    group by frequent_flyer_status_code
),
unique_customers_per_gender as (
    select
        gender,
        count(distinct customer_id) as tot_uq_cust_gender,
        round(count(distinct customer_id) * 100.0 /
            nullif((select total_uq_cust_overall from total_unique_customers), 0), 2)
            as gender_uq_cust_share_overall
    from customer_stats_base
    group by gender
),
customer_stats as (
    select
        ag.*,
        ucs.tot_uq_cust_status,
        usg.tot_uq_cust_gender,
        usg.gender_uq_cust_share_overall,
        tuc.total_uq_cust_overall,
        count(*) over () as total_bkgs_overall
    from customer_stats_base ag
    join unique_customers_per_status ucs on ag.frequent_flyer_status_code = ucs.frequent_flyer_status_code
    join unique_customers_per_gender usg on ag.gender = usg.gender
    cross join total_unique_customers tuc
)

select
    case
        when grouping(gender) = 1 and grouping(frq_flyer_status) = 1 then '(GRAND TOTAL)'
        when grouping(gender) = 1 then '(ALL)'
        else gender
    end as gender,
    case
        when grouping(frq_flyer_status) = 1 and grouping(gender) = 1 then '(GRAND TOTAL)'
        when grouping(frq_flyer_status) = 1 then '(ALL STATUSES)'
        else frq_flyer_status
    end as frq_flyer_status,

    max(total_bkgs_overall) as total_bkgs_overall,
    max(total_uq_cust_overall) as total_unique_customers_overall,
    case
        when grouping(gender) = 1 and grouping(frq_flyer_status) = 1
              -- grand total 100 underlines the percentage character of the column
            then round(count(distinct customer_id) * 100.0 / nullif(max(total_uq_cust_overall), 0), 2)
        when grouping(gender) = 1 then null   -- no gender share when gender is grouped away
        else max(gender_uq_cust_share_overall)
    end as gender_uq_cust_share_overall,

    count(*) as gender_status_bookings,
    round(count(*) * 100.0 / nullif(max(total_bkgs_overall), 0), 2) as gender_status_bkg_rate,

    case
        when grouping(gender) = 1 and grouping(frq_flyer_status) = 1
            then round(count(distinct customer_id) * 100.0 / nullif(max(total_uq_cust_overall), 0), 2)
        when grouping(gender) = 1 then null
        else round(count(distinct customer_id) * 100.0 / nullif(max(tot_uq_cust_gender), 0), 2)
    end as gender_uq_cust_share_by_status,

    case
        when grouping(frq_flyer_status) = 1 and grouping(gender) = 1
            then round(count(distinct customer_id) * 100.0 / nullif(max(total_uq_cust_overall), 0), 2)
        when grouping(frq_flyer_status) = 1 then null
        else round(count(distinct customer_id) * 100.0 / nullif(max(tot_uq_cust_status), 0), 2)
    end as status_uq_cust_share_by_gender
from customer_stats
group by grouping sets ((gender, frq_flyer_status), gender, frq_flyer_status, ())
order by gender, frq_flyer_status;