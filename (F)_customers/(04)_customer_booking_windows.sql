/*
--------------------------------------------------------------------------------------------
Booking Lead Times by Customer Age Group and Gender
--------------------------------------------------------------------------------------------
Goal:
    Analyze how booking lead times (time between booking a flight and flight date) vary by
    customer age group and gender.

Contents and Structure:
    - The query provides average and maximum lead times per customer group, as well as
      the standard deviations (all in days).
    - The query shows what percentage of each customer group's bookings falls into each of
      the following lead time windows: 4 weeks, 6 weeks, 8 weeks, 10 weeks, 12 weeks, and
      more than 12 weeks
    - Values are shown for each combination of age group and gender, for group subtotals
      (all age groups per gender | all genders per age group), and as grand total.
--------------------------------------------------------------------------------------------
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
        c.customer_id,
        case when c.gender = 'female' then '(1) Female' else '(2) Male' end as gender,
        date_part('year', age(l.latest_flight_date, c.date_of_birth)) +
            extract(day from age(l.latest_flight_date, c.date_of_birth)) / 365.25 as age,
        floor(extract(epoch from (f.flight_date - b.booking_time)) / (60 * 60 * 24)) as bkg_lead_time_days
    from bookings_2023 b
    join flights f on b.flight_number = f.flight_number
    join customers c on b.customer_id = c.customer_id
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
    from customer_stats
)
select
    case
        when grouping(age_group) = 1 and grouping(gender) = 0 then '(ALL)'
        when grouping(age_group) = 1 and grouping(gender) = 1 then '(GRAND TOTAL)'
        else age_group end as age_group,
    case
        when grouping(gender) = 1 and grouping(age_group) = 0 then '(ALL)'
        when grouping(gender) = 1 and grouping(age_group) = 1 then '(GRAND TOTAL)'
        else gender end as gender,
    count(*) as total_bookings,
    round(avg(bkg_lead_time_days), 2) as avg_bkg_lead_time_days,
    max(bkg_lead_time_days) as max_bkg_lead_time_days,
    round(stddev(bkg_lead_time_days), 2) as bkg_lead_time_stddev_days,
    round(count(*) filter (where bkg_lead_time_days <= 28) * 100.0 / nullif(count(*), 0), 2)
        as pct_bkgs_within_4w_window,
    round(count(*) filter (where bkg_lead_time_days > 28 and bkg_lead_time_days <= 42) * 100.0 / nullif(count(*), 0), 2)
        as pct_bkgs_within_6w_window,
    round(count(*) filter (where bkg_lead_time_days > 42 and bkg_lead_time_days <= 56) * 100.0 / nullif(count(*), 0), 2)
        as pct_bkgs_within_8w_window,
    round(count(*) filter (where bkg_lead_time_days > 56 and bkg_lead_time_days <= 70) * 100.0 / nullif(count(*), 0), 2)
        as pct_bkgs_within_10w_window,
    round(count(*) filter (where bkg_lead_time_days > 70 and bkg_lead_time_days <= 84) * 100.0 / nullif(count(*), 0), 2)
        as pct_bkgs_within_12w_window,
    round(count(*) filter (where bkg_lead_time_days > 84) * 100.0 / nullif(count(*), 0), 2)
        as pct_bkgs_over_12w_window
from age_groups
group by grouping sets ((age_group, gender), age_group, gender, ())
order by age_group, gender;