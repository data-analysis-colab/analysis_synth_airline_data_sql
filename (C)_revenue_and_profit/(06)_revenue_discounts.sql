/*
--------------------------------------------------------------------------------------------------------
Revenue Impact of Frequent Flyer Discounts
--------------------------------------------------------------------------------------------------------
Purpose:
- Compares the impact of granting frequent flyer discounts for ticket prices on revenue across
  flyer statuses/tiers and passenger classes.
--------------------------------------------------------------------------------------------------------
Notes:
- The *total nominal revenue* is the revenue in the hypothetical scenario where every customer had
  paid the full ticket price (meaning no discounts had been granted).
- The info-column status_discount_pct shows the fixed ticket price reductions that are granted for
  each flyer status/tier as percentages. No values are displayed for status subtotals and the grand
  total.
- The column avg_discount_pct calculates the effective averages for granted discounts as percentages,
  replicating the values from status_discount_pct for each status, but also fills in values for
  subtotals and the grand total.
--------------------------------------------------------------------------------------------------------
*/

with class_prices as (
    select
        b.customer_id,
        case
            when b.class_name = 'Economy' then '(1) Economy'
            when b.class_name = 'Business' then '(2) Business'
            when b.class_name = 'First' then '(3) First'
        end as class_name,
        ffd.frequent_flyer_status,
        ffd.frequent_flyer_discount_pct as discount_pct,
        case
            when b.class_name = 'Economy' then r.price_economy
            when b.class_name = 'Business' then r.price_business
            when b.class_name = 'First' then r.price_first
        end as class_price,
        b.price_paid
    from bookings b
    join flights f on b.flight_number = f.flight_number and b.flight_date = f.flight_date
    join routes r on f.line_number = r.line_number
    join frequent_flyer_discounts ffd on b.frequent_flyer_status_code = ffd.frequent_flyer_status_code
    where b.flight_cxl_refund = FALSE
),
discounts as (
    select
        *,
        class_price - price_paid as discount
    from class_prices
)
select
    case
        when grouping(frequent_flyer_status) = 1 and grouping(class_name) = 1 then 'GRAND TOTAL (ALL)'
        when grouping(frequent_flyer_status) = 1 then 'SUBTOTAL (ALL)'
        else frequent_flyer_status
    end as frequent_flyer_status,
    case
        when grouping(class_name) = 1 and grouping(frequent_flyer_status) = 1 then 'GRAND TOTAL (ALL)'
        when grouping(class_name) = 1 then 'SUBTOTAL (ALL)'
        else class_name
    end as class_name,
    count(customer_id) as customer_count,
    round(case when frequent_flyer_status is not null then avg(discount_pct) end, 2) as status_discount_pct,
    round(avg(discount_pct), 2) as avg_discount_pct,
    round(sum(class_price)) as tot_rev_nominal,
    round(sum(price_paid)) as tot_rev_after_disc,
    round(sum(discount)) as tot_discounts,
    round(avg(discount), 2) as avg_discount
from discounts
group by grouping sets (
    (frequent_flyer_status, class_name),
    (frequent_flyer_status),
    (class_name),
    ()
)
order by
    case
        when frequent_flyer_status = 'None' or frequent_flyer_status = 'No Status' then 1
        when frequent_flyer_status = 'Basic' then 2
        when frequent_flyer_status = 'Silver' then 3
        when frequent_flyer_status = 'Gold' then 4
        when frequent_flyer_status = 'Platinum' then 5
        when frequent_flyer_status = 'SUBTOTAL (ALL)' then 6
        when frequent_flyer_status = 'GRAND TOTAL (ALL)' then 7
    end,
    class_name;