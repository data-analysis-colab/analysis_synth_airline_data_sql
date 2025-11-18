/*
--------------------------------------------------------------------------------------------
Customer Age Group vs. Passenger Class Preferences
--------------------------------------------------------------------------------------------
Goal:
    Analyze how different customer age groups distribute their bookings across passenger
    classes (Economy, Business, First), taking into account the flight's cabin configuration
    (i.e., which classes were actually available).

    Flights with “Economy only” configuration are excluded since there is no meaningful
    class choice.

Key design:
    • Canonical customer age is based on each customer’s latest recorded flight.
    • Age groups are derived from canonical ages to avoid counting the same person
      across multiple groups.
    • Both age-group-specific and class-specific booking shares are provided, as well
      as totals and subtotals across cabin configurations.

--------------------------------------------------------------------------------------------
Output column legend:
--------------------------------------------------------------------------------------------

cabin_configuration
    - The available cabin mix on a flight:
        (1) Economy, Business
        (2) Economy, Business, First
      Grouping levels:
        • (ALL CONFIGURATIONS): subtotal across all cabin configurations
        • (GRAND TOTAL): grand total across all data

age_group
    - Customer age group based on canonical age (age at time of the latest flight):
        (1) Age <= 24
        (2) Age 25–34
        (3) Age 35–44
        (4) Age 45–60
        (5) Age > 60
      Grouping levels:
        • (ALL GROUPS): subtotal across all age groups
        • (GRAND TOTAL): grand total across all data

passenger_class
    - The booked passenger class:
        (1) Economy, (2) Business, (3) First
      Grouping levels:
        • (ALL CLASSES): subtotal across all passenger classes
        • (GRAND TOTAL): grand total across all data

--------------------------------------------------------------------------------------------
Metric columns:
--------------------------------------------------------------------------------------------

total_bkgs_overall
    → Total number of bookings in the source period (constant across rows).

age_group_bkg_share_overall
    → Percentage of total bookings made by this age group (ignores class breakdowns).
      For example, “Age 25–34 accounts for 28.4% of all bookings overall.”

age_grp_cl_bookings
    → Absolute number of bookings for this specific combination of age group and
      passenger class.

age_grp_class_bkg_rate
    → Percentage share of total bookings represented by this age group × class
      combination.
      For example, “Age 25–34 + Business accounts for 8.7% of total bookings.”

age_grp_bkg_share_by_cl
    → Within-age-group percentage distribution of class choices.
      For example, “Among Age 25–34, 78.2% chose Economy, 18.5% Business, 3.3% First.”

cl_bkg_share_by_age_grp
    → Within-class percentage distribution of age groups.
      For example, “Within Business Class, 31.4% of bookings come from Age 25–34.”

--------------------------------------------------------------------------------------------
Interpretation guide:
--------------------------------------------------------------------------------------------
• “Age group share overall” helps compare the relative market weight of each demographic.
• “Within-age-group class share” shows how class preferences shift with age.
• “Within-class age share” shows which demographics dominate each cabin.
• Grand totals and subtotals act as validation checkpoints: all share columns should
  logically sum to ≈100% where applicable.
--------------------------------------------------------------------------------------------
This query has been visualized with Matplotlib.
See /visualizations/english/(10)_age_classes_heatmap.png
and /visualizations/german/(10)_alter_klassen_heatmap.png
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
customer_stats as (
    select
        case
            when fbp.cabin_configuration = 'Economy, Business' then '(1) Economy, Business'
            when fbp.cabin_configuration = 'Economy, Business, First' then '(2) Economy, Business, First'
        end as cabin_configuration,
        date_part('year', age(l.latest_flight_date, c.date_of_birth))
            + extract(day from age(l.latest_flight_date, c.date_of_birth)) / 365.25 as age,
        case
            when b.class_name = 'Economy' then '(1) Economy'
            when b.class_name = 'Business' then '(2) Business'
            when b.class_name = 'First' then '(3) First'
        end as class_name,
        count(*) over () as total_bkgs_overall,
        count(*) over (partition by cabin_configuration) as total_bkgs_config,
        count(*) over (partition by b.class_name, cabin_configuration) as tot_bkgs_class
    from bookings_2023 b
    join customers c on b.customer_id = c.customer_id
    join latest_flights l on c.customer_id = l.customer_id
    join flights_booked_passengers fbp on b.flight_number = fbp.flight_number
    where c.date_of_birth is not null and fbp.cabin_configuration != 'Economy only'
),
age_groups as (
    select
        case
            when age <= 24 then '(1) Age <= 24'
            when age <= 34 then '(2) Age 25-34'
            when age <= 44 then '(3) Age 35-44'
            when age <= 60 then '(4) Age 45-60'
            when age > 60 then '(5) Age > 60'
        end as age_group,
        *
    from customer_stats
),
ag_total as (
    select
        *,
        count(*) over (partition by age_group, cabin_configuration) as tot_bkgs_age_group,
        round(count(*) over (partition by age_group) * 100.0 / nullif(total_bkgs_overall, 0), 2)
            as age_group_share_overall
    from age_groups
)

select
    case
        when grouping(cabin_configuration) = 1 and
             grouping(age_group) = 1 and
             grouping(class_name) = 1
            then '(GRAND TOTAL)'
        when grouping(cabin_configuration) = 1 then '(ALL CONFIGURATIONS)'
        else cabin_configuration
    end as cabin_configuration,

    case
        when grouping(age_group) = 1 and
             grouping(class_name) = 1 and
             grouping(cabin_configuration) = 1
            then '(GRAND TOTAL)'
        when grouping(age_group) = 1 then '(ALL GROUPS)'
        else age_group
    end as age_group,

    case
        when grouping(class_name) = 1 and
             grouping(age_group) = 1  and
             grouping(cabin_configuration) = 1
            then '(GRAND TOTAL)'
        when grouping(class_name) = 1 then '(ALL CLASSES)'
        else class_name
    end as passenger_class,

    max(total_bkgs_overall) as total_bkgs_overall,

    case
        when grouping(age_group) = 1 and
             grouping(class_name) = 1 and
             grouping(cabin_configuration) = 1
              -- grand total 100 underlines the percentage character of the column
            then round(count(*) * 100.0 / nullif(max(total_bkgs_overall), 0), 2)
        when grouping(age_group) = 1 then null   -- no age group share when age is grouped away
        else max(age_group_share_overall)
    end as age_group_bkg_share_overall,

    count(*) as age_grp_cl_bookings,
    case
        when grouping(cabin_configuration) = 1
            then round(count(*) * 100.0 / nullif(max(total_bkgs_overall), 0), 2)
        else round(count(*) * 100.0 / nullif(max(total_bkgs_config), 0), 2)
    end as age_grp_class_bkg_rate,

    case
        when (grouping(age_group) = 1 and grouping(class_name) = 1) or
             (grouping(cabin_configuration) = 1 and grouping(class_name) = 1)
            then round(count(*) * 100.0 / nullif(max(total_bkgs_overall), 0), 2)
        when grouping(age_group) = 1 then null
        else round(count(*) * 100.0 / nullif(max(tot_bkgs_age_group), 0), 2)
    end as age_grp_bkg_share_by_cl,

    case
        when (grouping(class_name) = 1 and grouping(age_group) = 1) or
             (grouping(cabin_configuration) = 1 and grouping(age_group) = 1)
            then round(count(*) * 100.0 / nullif(max(total_bkgs_overall), 0), 2)
        when grouping(class_name) = 1 then null
        else round(count(*) * 100.0 / nullif(max(tot_bkgs_class), 0), 2)
    end as cl_bkg_share_by_age_grp
from ag_total
group by grouping sets ((cabin_configuration, age_group, class_name), age_group, class_name, ())
order by cabin_configuration, age_group, passenger_class;