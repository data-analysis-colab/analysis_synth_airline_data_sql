/*
--------------------------------------------------------------------------------------------
Missed Check-Ins by Age Group and Gender
--------------------------------------------------------------------------------------------
Goal:
    Show how likely customers within a certain age group or of a certain gender are to
    check in for their booked flights vs. miss their check-ins.

Output:
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
        case when c.gender = 'female' then '(1) Female' else '(2) Male' end as gender,
        date_part('year', age(l.latest_flight_date, c.date_of_birth)) +
            extract(day from age(l.latest_flight_date, c.date_of_birth)) / 365.25 as age,
        b.checked_in
    from bookings_2023 b
    left join customers c on b.customer_id = c.customer_id
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
        end as age_group,
        *
    from customer_stats
)
select
    case
        when grouping(gender) = 1 and grouping(age_group) = 1 then '(GRAND TOTAL)'
        when grouping(gender) = 1 then '(ALL)'
        else gender
    end as gender,
    case
        when grouping(age_group) = 1 and grouping(gender) = 1 then '(GRAND TOTAL)'
        when grouping(age_group) = 1 then '(ALL)'
        else age_group
    end as age_group,
    count(*) as bookings,
    round(count(*) filter (where checked_in = true) * 100.0 / count(*), 2) as check_in_rate,
    count(*) filter (where checked_in = false) as missed_check_ins,
    round(count(*) filter (where checked_in = false) * 100.0 / count(*), 2) as missed_check_in_rate
from age_groups
group by grouping sets ((gender, age_group), gender, age_group, ())
order by age_group, gender;