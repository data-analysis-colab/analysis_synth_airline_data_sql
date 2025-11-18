/*
--------------------------------------------------------------------------------------------------------
Weather-Related Flight Cancellation Constellations by Distance Category
--------------------------------------------------------------------------------------------------------
Purpose:
    Identifies all weather constellation types that most frequently coincide with
    **weather-induced flight cancellations**, grouped by route distance category.

Dependencies:
    - View: hazardous_weather_constellations
        → Defines hazardous weather combinations relevant to both delay and cancellation logic.

Procedural overview:
    1.  The first CTE (`weather_cxl_intervals`) determines an **observation window**
        around each canceled flight’s *scheduled departure time*.

        • These intervals represent the period during which hazardous weather must
          **persist continuously** to cause a cancellation rather than just a delay.

        • The duration of persistence depends on the flight’s distance category:
              – Short-haul: 2 hours continuous hazardous weather
              – Medium-haul: 3 hours continuous hazardous weather
              – Long-haul: 4 hours continuous hazardous weather

        • Observation windows for analysis are slightly shorter (1h, 2h, 3h respectively)
          to reflect the monitoring horizon relative to scheduled departure.

    2.  The second CTE (`weather_cxl_obs`) joins these intervals with
        `hazardous_weather_constellations` to capture all recorded weather constellations
        observed at the corresponding airport within each flight’s cancellation window.

    3.  The aggregation steps (`constellation_counts`, `constellation_shares`)
        count and normalize each constellation type by distance category,
        producing per-category and overall percentage distributions.

Interpretation:
    • Each constellation represents a combination of conditions such as Fog, Blizzard,
      Sandstorm, Extreme Wind, or Extreme Temperatures.

    • Higher shares indicate weather combinations most commonly associated with
      **actual cancellations** rather than delays.

Output summary:
    • weather_cancellation_constellation — hazardous weather pattern
    • const_share_* — relative share by distance category
    • const_share_overall_pct — overall share across all weather-related cancellations
    • Final row (‘GRAND TOTAL’) normalizes totals to 100% across all categories

--------------------------------------------------------------------------------------------------------
*/

with weather_cxl_intervals as (
    select
        f.flight_number,
        r.departure_airport_code as airport_code,
        f.scheduled_departure as obs_time,
        case
            when r.distance_km < 1500 then interval '1 hour'
            when r.distance_km < 5000 then interval '2 hours'
            else interval '3 hours'
        end as obs_window,
        case when r.distance_km < 1500 then 1 else 0 end as short_haul_flight,
        case when r.distance_km >= 1500 and r.distance_km < 5000 then 1 else 0 end as medium_haul_flight,
        case when r.distance_km >= 5000 then 1 else 0 end as long_haul_flight
    from flights f
    join routes r on f.line_number = r.line_number
    where f.cancellation_reason = 'Weather'
),
weather_cxl_obs as (
    select
        wdi.flight_number,
        wdi.short_haul_flight,
        wdi.medium_haul_flight,
        wdi.long_haul_flight,
        hwc.constellation
    from weather_cxl_intervals wdi
    join hazardous_weather_constellations hwc on hwc.airport_code = wdi.airport_code and
            hwc.observation_time between wdi.obs_time - interval '1 hour' and wdi.obs_time + wdi.obs_window
),
constellation_counts as (
    select
        constellation,
        sum(short_haul_flight) as const_count_short_haul,
        sum(medium_haul_flight) as const_count_medium_haul,
        sum(long_haul_flight) as const_count_long_haul,
        count(*) as const_count_total
    from weather_cxl_obs
    group by constellation
),
constellation_shares as (
    select
        constellation as weather_cancellation_constellation,
        round(const_count_short_haul * 100.0 / sum(const_count_short_haul) over (), 2)
            as const_share_short_haul_pct,
        round(const_count_medium_haul * 100.0 / sum(const_count_medium_haul) over (), 2)
            as const_share_medium_haul_pct,
        round(const_count_long_haul * 100.0 / sum(const_count_long_haul) over (), 2)
            as const_share_long_haul_pct,
        round(const_count_total * 100.0 / sum(const_count_total) over (), 2)
            as const_share_overall_pct
    from constellation_counts
    order by const_share_overall_pct desc
)
select *
from constellation_shares
union all
select 'GRAND TOTAL',
       100.0,
       100.0,
       100.0,
       100.0;