/*
--------------------------------------------------------------------------------------------------------
Weather-Related Delay Constellations by Flight Phase and Distance Category
--------------------------------------------------------------------------------------------------------
Purpose:
    Identifies all weather constellation types that could plausibly cause departure or arrival delays
    for flights affected by hazardous weather conditions.

Dependencies:
    - View: hazardous_weather_constellations
        → Defines hazardous weather patterns relevant to departure and cancellation logic.
    - View: hazardous_weather_const_arr_dly
        → Defines hazardous weather patterns relevant to arrival delay logic.

Procedural overview:
    1.  The first two CTEs (`weather_delay_intervals_dep` and `weather_delay_intervals_arr`)
        define time intervals ("observation windows") preceding the *actual departure* or
        *actual arrival* of each non-canceled flight.

        • Departure windows are based on maximum tolerated delay durations before a flight
          would be considered canceled, which vary by distance category:
              – Short-haul: 2 hours
              – Medium-haul: 3 hours
              – Long-haul: 4 hours

        • Arrival windows are shorter because the underlying data simulation caps arrival delays at
          1–2 hours depending on route length.

    2.  The third CTE (`weather_delay_obs`) joins these interval definitions to the
        corresponding hazardous weather constellation views:
              – Departures ↔ `hazardous_weather_constellations`
              – Arrivals   ↔ `hazardous_weather_const_arr_dly`

        Each join retrieves *all hourly weather observations* within the flight’s
        defined observation window at the relevant airport (departure or arrival).
        This ensures that any hazardous condition that could have contributed to a delay
        during the observed time frame is captured.

    3.  The following aggregation steps (`constellation_counts`, `constellation_shares`)
        count and normalize the frequency of each constellation by:
              • Flight phase (Departure vs. Arrival)
              • Distance category (Short-, Medium-, Long-haul)
        The resulting percentages show which hazardous weather types most frequently coincide
        with delayed flights, separated by flight phase and route length.

Output summary:
    • phase — 'Departure' or 'Arrival'
    • weather_delay_constellation — hazardous weather combination
    • const_share_* — relative share of each constellation among delayed flights
    • const_count_total — total occurrences per constellation
    • (TOTAL) row — normalized 100% totals per phase

--------------------------------------------------------------------------------------------------------
*/

with weather_delay_intervals_dep as (
    select
        f.flight_number,
        '(1) Departure' as phase,
        r.departure_airport_code as airport_code,
        f.actual_departure as obs_time,
        case
            when r.distance_km < 1500 then interval '2 hours'
            when r.distance_km < 5000 then interval '3 hours'
            else interval '4 hours'
        end as obs_window,
        case when r.distance_km < 1500 then 1 else 0 end as short_haul_flight,
        case when r.distance_km >= 1500 and r.distance_km < 5000 then 1 else 0 end as medium_haul_flight,
        case when r.distance_km >= 5000 then 1 else 0 end as long_haul_flight
    from flights f
    join routes r on f.line_number = r.line_number
    where cancelled = FALSE
),
weather_delay_intervals_arr as (
    select
        f.flight_number,
        '(2) Arrival' as phase,
        r.arrival_airport_code as airport_code,
        f.actual_arrival as obs_time,
        case
            when r.distance_km < 1500 then interval '1 hour'
            else interval '2 hours'
        end as obs_window,
        case when r.distance_km < 1500 then 1 else 0 end as short_haul_flight,
        case when r.distance_km >= 1500 and r.distance_km < 5000 then 1 else 0 end as medium_haul_flight,
        case when r.distance_km >= 5000 then 1 else 0 end as long_haul_flight
    from flights f
    join routes r on f.line_number = r.line_number
    where cancelled = FALSE
),
weather_delay_obs as (
    -- Departure delay observations
    select
        wdid.flight_number,
        wdid.phase,
        wdid.short_haul_flight,
        wdid.medium_haul_flight,
        wdid.long_haul_flight,
        hwc.constellation
    from weather_delay_intervals_dep wdid
    join hazardous_weather_constellations hwc on hwc.airport_code = wdid.airport_code and
            hwc.observation_time between (wdid.obs_time - wdid.obs_window) and wdid.obs_time

    union all

    -- Arrival delay observations
    select
        wdia.flight_number,
        wdia.phase,
        wdia.short_haul_flight,
        wdia.medium_haul_flight,
        wdia.long_haul_flight,
        hwa.constellation
    from weather_delay_intervals_arr wdia
    join hazardous_weather_const_arr_dly hwa on hwa.airport_code = wdia.airport_code and
            hwa.observation_time between (wdia.obs_time - wdia.obs_window) and wdia.obs_time
),
constellation_counts as (
    select
        phase,
        constellation,
        sum(short_haul_flight) as const_count_short_haul,
        sum(medium_haul_flight) as const_count_medium_haul,
        sum(long_haul_flight) as const_count_long_haul,
        count(*) as const_count_total
    from weather_delay_obs
    group by phase, constellation
),
constellation_shares as (
    select
        phase,
        constellation as weather_delay_constellation,
        round(const_count_short_haul * 100.0 / sum(const_count_short_haul) over (partition by phase), 2)
            as const_share_short_haul,
        round(const_count_medium_haul * 100.0 / sum(const_count_medium_haul) over (partition by phase), 2)
            as const_share_medium_haul,
        round(const_count_long_haul * 100.0 / sum(const_count_long_haul) over (partition by phase), 2)
            as const_share_long_haul,
        round(const_count_total * 100.0 / sum(const_count_total) over (partition by phase), 2)
            as const_share_total,
        const_count_total
    from constellation_counts
)
select *
from constellation_shares
union all
select
    concat(phase, ' (TOTAL)'),
    'GRAND TOTAL',
    100.00,
    100.00,
    100.00,
    100.00,
    sum(const_count_total)
from constellation_shares
group by phase
order by phase, const_share_total desc;