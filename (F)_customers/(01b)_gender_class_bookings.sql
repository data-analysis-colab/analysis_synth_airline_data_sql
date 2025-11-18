/*
-----------------------------------------------------------------------------------------------
Customer Gender vs. Passenger Class Preferences
-----------------------------------------------------------------------------------------------
Goal:
    Analyze how female vs. male customers distribute their bookings across passenger
    classes (Economy, Business, First), taking into account the flight's cabin configuration
    (i.e., which classes were actually available).

    Flights with “Economy only” configuration are excluded since there is no meaningful
    class choice.

Key design:
    • Both gender-specific and class-specific booking shares are provided, as well
      as totals and subtotals across cabin configurations.

-----------------------------------------------------------------------------------------------
Output column legend:
-----------------------------------------------------------------------------------------------

cabin_configuration
    - The available cabin mix on a flight:
        (1) Economy, Business
        (2) Economy, Business, First
      Grouping levels:
        • (ALL CONFIGURATIONS): subtotal across all cabin configurations
        • (GRAND TOTAL): grand total across all data

gender
    - Customer gender
      Grouping levels:
        • (ALL): subtotal across all genders
        • (GRAND TOTAL): grand total across all data

passenger_class
    - The booked passenger class:
        (1) Economy, (2) Business, (3) First
      Grouping levels:
        • (ALL CLASSES): subtotal across all passenger classes
        • (GRAND TOTAL): grand total across all data

-----------------------------------------------------------------------------------------------
Metric columns:
-----------------------------------------------------------------------------------------------

total_bkgs_overall
    → Total number of bookings in the source period (constant across rows).

gender_bkg_share_overall
    → Percentage of total bookings made by customers of this gender (ignores class breakdowns).
      For example, “Female customers account for 47.4% of all bookings overall.”

gender_cl_bookings
    → Absolute number of bookings for this specific combination of gender and
      passenger class.

gender_class_bkg_rate
    → Percentage share of total bookings represented by this gender × class
      combination.
      For example, “Female + Business accounts for 5.2% of total bookings.”

gender_bkg_share_by_cl
    → Within-gender-group percentage distribution of class choices.
      For example, “Among female customers, 74.8% chose Economy, 19.8% Business, 5.4% First.”

cl_bkg_share_by_gender
    → Within-class percentage distribution of gender.
      For example, “Within Business Class, 46.3% of bookings come from female customers.”

-----------------------------------------------------------------------------------------------
Interpretation guide:
-----------------------------------------------------------------------------------------------
• “Gender share overall” helps compare the relative market weight of each demographic.
• “Within-gender-group class share” shows how class preferences shift with gender.
• “Within-class gender share” shows which demographics dominate each cabin.
• Grand totals and subtotals act as validation checkpoints: all share columns should
  logically sum to ≈100% where applicable.
-----------------------------------------------------------------------------------------------
*/

with customer_stats as (
    select
        case
            when fbp.cabin_configuration = 'Economy, Business' then '(1) Economy, Business'
            when fbp.cabin_configuration = 'Economy, Business, First' then '(2) Economy, Business, First'
        end as cabin_configuration,
        case when c.gender = 'female' then '(1) Female' else '(2) Male' end as gender,
        case
            when b.class_name = 'Economy' then '(1) Economy'
            when b.class_name = 'Business' then '(2) Business'
            when b.class_name = 'First' then '(3) First'
        end as class_name,
        count(*) over () as total_bkgs_overall,
        count(*) over (partition by cabin_configuration) as total_bkgs_config,
        round(count(*) over (partition by gender) * 100.0 / nullif(count(*) over (), 0), 2)
            as gender_share_overall,
        count(*) over (partition by gender, cabin_configuration) as tot_bkgs_gender,
        count(*) over (partition by b.class_name, cabin_configuration) as tot_bkgs_class
    from bookings_2023 b
    join customers c on b.customer_id = c.customer_id
    join flights_booked_passengers fbp on b.flight_number = fbp.flight_number
    where c.date_of_birth is not null and fbp.cabin_configuration != 'Economy only'
)

select
    case
        when grouping(cabin_configuration) = 1 and
             grouping(gender) = 1 and
             grouping(class_name) = 1
            then '(GRAND TOTAL)'
        when grouping(cabin_configuration) = 1 then '(ALL CONFIGURATIONS)'
        else cabin_configuration
    end as cabin_configuration,

    case
        when grouping(gender) = 1 and
             grouping(class_name) = 1 and
             grouping(cabin_configuration) = 1
            then '(GRAND TOTAL)'
        when grouping(gender) = 1 then '(ALL)'
        else gender
    end as gender,

    case
        when grouping(class_name) = 1 and
             grouping(gender) = 1  and
             grouping(cabin_configuration) = 1
            then '(GRAND TOTAL)'
        when grouping(class_name) = 1 then '(ALL CLASSES)'
        else class_name
    end as passenger_class,

    max(total_bkgs_overall) as total_bkgs_overall,

    case
        when grouping(gender) = 1 and
             grouping(class_name) = 1 and
             grouping(cabin_configuration) = 1
            -- grand total 100 underlines the percentage character of the column
            then round(count(*) * 100.0 / nullif(max(total_bkgs_overall), 0), 2)
        when grouping(gender) = 1 then null   -- no gender share when gender is grouped away
        else max(gender_share_overall)
    end as gender_bkg_share_overall,

    count(*) as gender_cl_bookings,
    case
        when grouping(cabin_configuration) = 1
            then round(count(*) * 100.0 / nullif(max(total_bkgs_overall), 0), 2)
        else round(count(*) * 100.0 / nullif(max(total_bkgs_config), 0), 2)
    end as gender_class_bkg_rate,

    case
        when (grouping(gender) = 1 and grouping(class_name) = 1) or
             (grouping(cabin_configuration) = 1 and grouping(class_name) = 1)
            then round(count(*) * 100.0 / nullif(max(total_bkgs_overall), 0), 2)
        when grouping(gender) = 1 then null
        else round(count(*) * 100.0 / nullif(max(tot_bkgs_gender), 0), 2)
    end as gender_bkg_share_by_cl,

    case
        when (grouping(class_name) = 1 and grouping(gender) = 1) or
             (grouping(cabin_configuration) = 1 and grouping(gender) = 1)
            then round(count(*) * 100.0 / nullif(max(total_bkgs_overall), 0), 2)
        when grouping(class_name) = 1 then null
        else round(count(*) * 100.0 / nullif(max(tot_bkgs_class), 0), 2)
    end as cl_bkg_share_by_gender
from customer_stats
group by grouping sets ((cabin_configuration, gender, class_name), gender, class_name, ())
order by cabin_configuration, gender, passenger_class;