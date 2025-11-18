-- add booked_total to flights, which is the nominal passenger count before cancellations and missed check-ins,
-- add cabin_configuration
create or replace view flights_booked_passengers as
    with booked_passengers as (
        select
            flight_number,
            sum(class_bookings) as booked_total
        from flight_capacity_by_class
        group by flight_number
    ),
    flights_without_business_cl as (
        select flight_number
        from flight_capacity_by_class
        where class_name = 'Business' and capacity = 0
    ),
    flights_with_first_cl as (
        select flight_number
        from flight_capacity_by_class
        where class_name = 'First' and capacity > 0
    ),
    cabin_configurations as (
    select
        f.flight_number,
        case
            when f.flight_number in (select flight_number from flights_with_first_cl)
                then 'Economy, Business, First'
            when f.flight_number in (select flight_number from flights_without_business_cl)
                then 'Economy only'
            else 'Economy, Business'
        end as cabin_configuration
    from flights f
    )
    select
        f.flight_number,
        f.flight_date,
        f.line_number,
        cc.cabin_configuration as cabin_configuration,
        f.aircraft_id,
        bp.booked_total,
        f.passengers_total,
        f.scheduled_departure,
        f.scheduled_arrival,
        f.actual_departure,
        f.actual_arrival,
        f.cancelled,
        f.cancellation_reason,
        f.delay_reason_dep,
        f.delay_reason_arr
    from flights f
    join booked_passengers bp on f.flight_number = bp.flight_number
    join cabin_configurations cc on f.flight_number = cc.flight_number
    order by f.flight_number, f.flight_date;



-- creating table instead of view here for performance reasons:
-- add actual passenger counts (after cancellations and missed check-ins) to flight_capacity_by_class,
create table flight_capacity_by_class_passengers (
    flight_number varchar(10),
    flight_date date,
    class_name varchar(20),
    capacity int,
    class_bookings int,
    class_passengers int default 0,
    primary key (flight_number, flight_date, class_name),
    foreign key (flight_number, flight_date) references flights(flight_number, flight_date),
    check (class_bookings <= capacity)
);

insert into flight_capacity_by_class_passengers
select
    fcc.flight_number,
    fcc.flight_date,
    fcc.class_name,
    fcc.capacity,
    fcc.class_bookings,
    COALESCE(chip.class_passengers, 0)
from flight_capacity_by_class fcc
left join (
    select
        flight_number,
        class_name,
        count(customer_id) as class_passengers
    from bookings
    where checked_in = true
    group by flight_number, class_name
) chip on fcc.flight_number = chip.flight_number and fcc.class_name = chip.class_name;



-- create a lookup table for country timezones
create table country_timezones (
    country varchar(100) primary key,
    timezone varchar(100) not null
);

insert into country_timezones (country, timezone) values
    ('Australia', 'Australia/Sydney'),
    ('Austria', 'Europe/Vienna'),
    ('Brazil', 'America/Sao_Paulo'),
    ('Canada', 'America/Toronto'),         -- representative (Eastern)
    ('Denmark', 'Europe/Copenhagen'),
    ('Finland', 'Europe/Helsinki'),
    ('France', 'Europe/Paris'),
    ('Germany', 'Europe/Berlin'),
    ('Italy', 'Europe/Rome'),
    ('Netherlands', 'Europe/Amsterdam'),
    ('Norway', 'Europe/Oslo'),
    ('Poland', 'Europe/Warsaw'),
    ('Portugal', 'Europe/Lisbon'),
    ('Spain', 'Europe/Madrid'),
    ('Sweden', 'Europe/Stockholm'),
    ('Switzerland', 'Europe/Zurich'),
    ('United Kingdom', 'Europe/London'),
    ('United States', 'America/New_York'); -- representative (Eastern)