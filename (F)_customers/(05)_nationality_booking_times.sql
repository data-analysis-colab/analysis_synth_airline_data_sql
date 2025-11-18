/*
--------------------------------------------------------------------------------------------
Booking Times by Nationality
--------------------------------------------------------------------------------------------
Analyzes the distribution of booking times across nationalities,
both in UTC and local time (based on each country's timezone).
Also reports the most frequent and average booking hours
and compares each nationality's share of total bookings with
its share of total daily flights to/from that country.

Main outputs:
    • Total and relative booking volume by nationality
    • Most frequent and average booking hour (UTC & local)
    • % of bookings in morning / midday / evening / night (UTC)
    • % of total daily flights associated with each country
--------------------------------------------------------------------------------------------
*/

with nationalities as (
    select
        count(*) over () as total_bookings,
        c.nationality,
        b.booking_time::time as bkg_time_of_day,
        (b.booking_time at time zone 'UTC' at time zone tz.timezone)::time as booking_time_local,
        extract(hour from b.booking_time::time) as booking_hour,
        extract(hour from b.booking_time::time at time zone 'UTC' at time zone tz.timezone) as booking_hour_local
    from bookings_2023 b
    left join customers c on b.customer_id = c.customer_id
    left join country_timezones tz on c.nationality = tz.country
),
most_frequent_hours as (
    select
        nationality,
        booking_hour,
        booking_hour_local,
        count(*),
        row_number() over (partition by nationality order by count(*) desc) as rank
    from nationalities
    group by nationality, booking_hour, booking_hour_local
),
daily_flights as (
    select distinct
        ap.country,
        (
            (sum(r.flights_per_day) filter (where r.departure_airport_code = ap.airport_code)
                over (partition by ap.country) +
             sum(r.flights_per_day) filter (where r.arrival_airport_code = ap.airport_code)
                over (partition by ap.country)) * 100.0 /
            (sum(r.flights_per_day) filter (where r.departure_airport_code = ap.airport_code) over () +
             sum(r.flights_per_day) filter (where r.arrival_airport_code = ap.airport_code) over ())
        )
          as daily_flights_pct
    from routes r
    join airports ap on r.departure_airport_code = ap.airport_code or r.arrival_airport_code = ap.airport_code
)
select
    coalesce(n.nationality, 'GRAND TOTAL (ALL)') as country,
    count(*) as total_bookings,
    round(count(*) * 100.0 / nullif(max(n.total_bookings), 0), 2) as nationality_bkg_rate_pct,
    case
        when grouping(n.nationality) = 0 then round(max(df.daily_flights_pct), 2)
        else 100.0
    end as daily_flights_to_or_from_ctry_pct,
    max(m.booking_hour) as most_frq_bkg_hour_utc,
    avg(n.bkg_time_of_day)::time as avg_bkg_time_utc,
    round(count(*) filter (where bkg_time_of_day between time '06:00' and time '11:59')
        * 100.0 / nullif(count(*), 0), 2) as pct_bkgs_6_to_12_utc,
    round(count(*) filter (where bkg_time_of_day between time '12:00' and time '16:59')
        * 100.0 / nullif(count(*), 0), 2) as pct_bkgs_12_to_17_utc,
    round(count(*) filter (where bkg_time_of_day between time '17:00' and time '21:59')
        * 100.0 / nullif(count(*), 0), 2) as pct_bkgs_17_to_22_utc,
    round(count(*) filter (where bkg_time_of_day >= time '22:00' or bkg_time_of_day <= time '05:59')
        * 100.0 / nullif(count(*), 0), 2) as pct_bkgs_22_to_6_utc,
    max(m.booking_hour_local) as most_frq_bkg_hour_local,
    avg(n.booking_time_local)::time as avg_bkg_time_local
from nationalities n
left join (select nationality, booking_hour, booking_hour_local from most_frequent_hours where rank = 1) m
    on n.nationality = m.nationality
left join daily_flights df on n.nationality = df.country
group by cube(n.nationality)
order by n.nationality nulls last;