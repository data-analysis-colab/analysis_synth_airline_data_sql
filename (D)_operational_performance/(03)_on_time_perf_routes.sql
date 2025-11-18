/*
--------------------------------------------------------------------------------------------
Route-Level On-Time and Delay Distribution (Departure vs. Arrival)
--------------------------------------------------------------------------------------------
Goal:
    Provide an overview of route punctuality by classifying flights into delay-severity
    categories and aggregating results by route, phase (departure/arrival), and distance
    range. Includes both route-level detail and overall network averages.

Output Organization:
    - Sections (phases) are stacked using UNION ALL:
        (1-a) Departure    → top routes by on-time or severe delay ranking.
        (2-a) Arrival      → the same logic applied to arrival delays.
        (3-a) Overall      → combined departure and arrival indicators.
        (0)   Info-Row     → clarifies minute thresholds for each delay severity tier.
        (1-B → 3-B)        → grand-total averages across all routes for each phase.
    - Each section reports delay-rate percentages for severity bands
      (<5, 5–14, 15–29, 30–59, ≥60 min), average and max delay times,
      and the most-used aircraft model on that route.

Method Summary:
    1. flights_dep_delays | flights_arr_delays
         → Base delay minutes and route/aircraft info for non-canceled flights.
    2. dep_counts | arr_counts
         → Counts of flights in each delay severity band.
    3. dep_percentages | arr_percentages
         → Converts counts into per-route percentages.
    4. tot_percentages
         → Combines dep and arr data, adds rankings and distance categories.
    5. Final SELECTs
         → Filter top routes per rank_cap (default = 3) and append summary rows.

Interpretation:
    - “Top N On-Time-Rate” identifies routes with the highest punctuality.
    - “Top N Severe Dly-Rate” highlights routes most affected by long delays.
    - Distance categories (Short/Medium/Long-haul) aid contextual comparison.
--------------------------------------------------------------------------------------------
*/

with flights_dep_delays as (
    select
        r.line_number,
        extract(epoch from (f.actual_departure - f.scheduled_departure)) / 60 as delay_minutes,
        f.delay_reason_dep,
        r.distance_km,
        ac.model
    from flights f
    join routes r on f.line_number = r.line_number
    join aircraft ac on f.aircraft_id = ac.aircraft_id
    where cancelled = FALSE
),
flights_arr_delays as (
    select
        r.line_number,
        extract(epoch from (f.actual_arrival - f.scheduled_arrival)) / 60 as delay_minutes,
        f.delay_reason_arr,
        r.distance_km,
        f.aircraft_id,
        ac.model
    from flights f
    join routes r on f.line_number = r.line_number
    join aircraft ac on f.aircraft_id = ac.aircraft_id
    where cancelled = FALSE
),
most_used_aircraft_models as (
    select
        line_number,
        model,
        count(*) as model_count,
        row_number() over (partition by line_number order by count(*) desc) as rn
    from flights_dep_delays
    group by line_number, model
),

dep_counts as (
    select
        fdd.line_number,
        count(*) filter (where fdd.delay_minutes < 5) as dep_on_time_count,
        count(*) filter (where fdd.delay_minutes >= 5 and fdd.delay_minutes < 15) as dep_slight_dly_count,
        count(*) filter (where fdd.delay_minutes >= 15 and fdd.delay_minutes < 30) as dep_moderate_dly_count,
        count(*) filter (where fdd.delay_minutes >= 30 and fdd.delay_minutes < 60) as dep_substantial_dly_count,
        count(*) filter (where fdd.delay_minutes >= 60) as dep_severe_dly_count,
        count(*) as total_flights,
        min(fdd.distance_km) as distance_km,
        min(m.model) as most_used_aircraft_model,
        round(avg(fdd.delay_minutes), 2) as avg_dep_delay_minutes,
        round(max(fdd.delay_minutes), 2) as max_dep_delay_minutes
    from flights_dep_delays fdd
    left join (select line_number, model from most_used_aircraft_models where rn = 1) m
        on fdd.line_number = m.line_number
    group by fdd.line_number
),

arr_counts as (
    select
        fad.line_number,
        count(*) filter (where fad.delay_minutes < 5) as arr_on_time_count,
        count(*) filter (where fad.delay_minutes >= 5 and fad.delay_minutes < 15) as arr_slight_dly_count,
        count(*) filter (where fad.delay_minutes >= 15 and fad.delay_minutes < 30) as arr_moderate_dly_count,
        count(*) filter (where fad.delay_minutes >= 30 and fad.delay_minutes < 60) as arr_substantial_dly_count,
        count(*) filter (where fad.delay_minutes >= 60) as arr_severe_dly_count,
        count(*) as total_flights,
        min(fad.distance_km) as distance_km,
        min(m.model) as most_used_aircraft_model,
        round(avg(fad.delay_minutes), 2) as avg_arr_delay_minutes,
        round(max(fad.delay_minutes), 2) as max_arr_delay_minutes
    from flights_arr_delays fad
    left join (select line_number, model from most_used_aircraft_models where rn = 1) m
        on fad.line_number = m.line_number
    group by fad.line_number
),

dep_percentages as (
    select
        *,
        round(dep_on_time_count * 100.0 / nullif(total_flights, 0), 2) as dep_on_time_rate,
        round(dep_slight_dly_count * 100.0 / nullif(total_flights, 0), 2) as dep_slight_dly_rate,
        round(dep_moderate_dly_count * 100.0 / nullif(total_flights, 0), 2) as dep_moderate_dly_rate,
        round(dep_substantial_dly_count * 100.0 / nullif(total_flights, 0), 2) as dep_substantial_dly_rate,
        round(dep_severe_dly_count * 100.0 / nullif(total_flights, 0), 2) as dep_severe_dly_rate
    from dep_counts dc
),
arr_percentages as (
    select
        *,
        most_used_aircraft_model,
        round(arr_on_time_count * 100.0 / nullif(total_flights, 0), 2) as arr_on_time_rate,
        round(arr_slight_dly_count * 100.0 / nullif(total_flights, 0), 2) as arr_slight_dly_rate,
        round(arr_moderate_dly_count * 100.0 / nullif(total_flights, 0), 2) as arr_moderate_dly_rate,
        round(arr_substantial_dly_count * 100.0 / nullif(total_flights, 0), 2) as arr_substantial_dly_rate,
        round(arr_severe_dly_count * 100.0 / nullif(total_flights, 0), 2) as arr_severe_dly_rate
    from arr_counts
),
tot_percentages as (
    select
        concat(r.departure_airport_code, ' → ', arrival_airport_code) as route_name,

        (dp.total_flights + ap.total_flights) / 2 as total_flights,

        dp.dep_on_time_rate,
        dp.dep_slight_dly_rate,
        dp.dep_moderate_dly_rate,
        dp.dep_substantial_dly_rate,
        dp.dep_severe_dly_rate,

        ap.arr_on_time_rate,
        ap.arr_slight_dly_rate,
        ap.arr_moderate_dly_rate,
        ap.arr_substantial_dly_rate,
        ap.arr_severe_dly_rate,

        case
            when dp.distance_km < 1500 then 'Short-haul'
            when dp.distance_km >= 1500 and dp.distance_km < 5000 then 'Medium-haul'
            when dp.distance_km >= 5000 then 'Long-haul'
        end as distance_category,
        dp.most_used_aircraft_model,

        round((dp.dep_on_time_count + ap.arr_on_time_count) / 2 * 100 /
              ((dp.total_flights + ap.total_flights) / 2), 2)
            as tot_on_time_rate,
        round((dp.dep_slight_dly_count + ap.arr_slight_dly_count) / 2 * 100 /
              ((dp.total_flights + ap.total_flights) / 2), 2)
            as tot_slight_dly_rate,
        round((dp.dep_moderate_dly_count + ap.arr_moderate_dly_count) / 2 * 100 /
              ((dp.total_flights + ap.total_flights) / 2), 2)
            as tot_moderate_dly_rate,
        round((dp.dep_substantial_dly_count + ap.arr_substantial_dly_count) / 2 * 100 /
              ((dp.total_flights + ap.total_flights) / 2), 2)
           as tot_substantial_dly_rate,
        round((dp.dep_severe_dly_count + ap.arr_severe_dly_count) / 2 * 100 /
              ((dp.total_flights + ap.total_flights) / 2), 2)
           as tot_severe_dly_rate,

        dp.avg_dep_delay_minutes,
        ap.avg_arr_delay_minutes,
        round((dp.avg_dep_delay_minutes * dp.total_flights + ap.avg_arr_delay_minutes * ap.total_flights) /
              nullif((dp.total_flights + ap.total_flights), 0), 2) as avg_tot_delay_minutes,

        dp.max_dep_delay_minutes,
        ap.max_arr_delay_minutes,
        greatest(dp.max_dep_delay_minutes, ap.max_arr_delay_minutes) as max_tot_delay_minutes,

        row_number() over (order by dep_on_time_rate desc) as dep_on_time_rate_rank,
        row_number() over (order by arr_on_time_rate desc) as arr_on_time_rate_rank,
        row_number() over (order by (dp.dep_on_time_count + ap.arr_on_time_count) * 100.0 /
            nullif((dp.total_flights + ap.total_flights) / 2, 0) desc) as tot_on_time_rate_rank,

        row_number() over (order by dep_severe_dly_count desc) as dep_severe_dly_rate_rank,
        row_number() over (order by arr_severe_dly_count desc) as arr_severe_dly_rate_rank,
        row_number() over (order by (dp.dep_severe_dly_count + ap.arr_severe_dly_count) * 100.0 /
            nullif((dp.total_flights + ap.total_flights) / 2, 0) desc) as tot_severe_dly_rate_rank
    from dep_percentages dp
    join arr_percentages ap on dp.line_number = ap.line_number
    join routes r on dp.line_number = r.line_number
),

overall_most_used_aircraft_model as (
    select model
    from (select model, count(*) as cnt from flights_dep_delays group by model) sub
    order by cnt desc, model
    limit 1
),

params as (
    select 3 as rank_cap
)

select
    '(1-a) Departure' as phase,
    case
        when dep_on_time_rate_rank <= p.rank_cap and dep_severe_dly_rate_rank <= p.rank_cap            -- unlikely case
            then concat('Top ', p.rank_cap, ' On-Time-Rate & Top ', p.rank_cap, ' Severe Dly-Rate')
        when dep_on_time_rate_rank <= p.rank_cap then concat('Top ', p.rank_cap, ' On-Time-Rate')
        when dep_severe_dly_rate_rank <= p.rank_cap then concat('Top ', p.rank_cap, ' Severe Dly-Rate')
        else 'Medium/Low On-Time/Severe Dly Rank'
    end as route_on_time_perf_tier,
    route_name,
    distance_category,
    dep_on_time_rate as on_time_rate_pct,
    dep_slight_dly_rate as slight_dly_rate_pct,
    dep_moderate_dly_rate as moderate_dly_rate_pct,
    dep_substantial_dly_rate as substantial_dly_rate_pct,
    dep_severe_dly_rate as severe_dly_rate_pct,
    avg_dep_delay_minutes as avg_delay_minutes,
    max_dep_delay_minutes as max_delay_minutes,
    most_used_aircraft_model
from tot_percentages
cross join params p
where dep_on_time_rate_rank <= p.rank_cap or dep_severe_dly_rate_rank <= p.rank_cap

union all

select
    '(2-a) Arrival',
    case
        when arr_on_time_rate_rank <= p.rank_cap and arr_severe_dly_rate_rank <= p.rank_cap            -- unlikely case
            then concat('Top ', p.rank_cap, ' On-Time-Rate & Top ', p.rank_cap, ' Severe Dly-Rate')
        when arr_on_time_rate_rank <= p.rank_cap then concat('Top ', p.rank_cap, ' On-Time-Rate')
        when arr_severe_dly_rate_rank <= p.rank_cap then concat('Top ', p.rank_cap, ' Severe Dly-Rate')
        else 'Medium/Low On-Time/Severe Dly Perf.'
    end,
    route_name,
    distance_category,
    arr_on_time_rate,
    arr_slight_dly_rate,
    arr_moderate_dly_rate,
    arr_substantial_dly_rate,
    arr_severe_dly_rate,
    avg_arr_delay_minutes,
    max_arr_delay_minutes,
    most_used_aircraft_model
from tot_percentages
cross join params p
where arr_on_time_rate_rank <= p.rank_cap or arr_severe_dly_rate_rank <= p.rank_cap

union all

select
    '(3-a) Overall',
    case
        when tot_on_time_rate_rank <= p.rank_cap and tot_severe_dly_rate_rank <= p.rank_cap            -- unlikely case
            then concat('Top ', p.rank_cap, ' On-Time-Rate & Top ', p.rank_cap, ' Severe Dly-Rate')
        when tot_on_time_rate_rank <= p.rank_cap then concat('Top ', p.rank_cap, ' On-Time-Rate')
        when tot_severe_dly_rate_rank <= p.rank_cap then concat('Top ', p.rank_cap, ' Severe Dly-Rate')
        else 'Medium/Low On-Time/Severe Dly Perf.'
    end,
    route_name,
    distance_category,
    tot_on_time_rate,
    tot_slight_dly_rate,
    tot_moderate_dly_rate,
    tot_substantial_dly_rate,
    tot_severe_dly_rate,
    avg_tot_delay_minutes,
    max_tot_delay_minutes,
    most_used_aircraft_model
from tot_percentages
cross join params p
where tot_on_time_rate_rank <= p.rank_cap or tot_severe_dly_rate_rank <= p.rank_cap

union all

select
    '(0) INFO-ROW',
    'Info-row rate-columns-values = max dly-minutes thresholds',
    null,
    null,
    4,
    14,
    29,
    59,
    null,
    null,
    null,
    null

union all

select
    '(1-B) GRAND TOT DEP',
    '(ALL ROUTES AVERAGES)',
    null,
    '(ALL)',
    round(avg(dep_on_time_rate), 2),
    round(avg(dep_slight_dly_rate), 2),
    round(avg(dep_moderate_dly_rate), 2),
    round(avg(dep_substantial_dly_rate), 2),
    round(avg(dep_severe_dly_rate), 2),
    round(avg(avg_dep_delay_minutes), 2),
    round(avg(max_dep_delay_minutes), 2),
    min(om.model)
from tot_percentages, overall_most_used_aircraft_model om

union all

select
    '(2-B) GRAND TOT ARR',
    '(ALL ROUTES AVERAGES)',
    null,
    '(ALL)',
    round(avg(arr_on_time_rate), 2),
    round(avg(arr_slight_dly_rate), 2),
    round(avg(arr_moderate_dly_rate), 2),
    round(avg(arr_substantial_dly_rate), 2),
    round(avg(arr_severe_dly_rate), 2),
    round(avg(avg_arr_delay_minutes), 2),
    round(avg(max_arr_delay_minutes), 2),
    min(om.model)
from tot_percentages, overall_most_used_aircraft_model om

union all

select
    '(3-B) GRAND TOT ALL',
    '(ALL ROUTES AVERAGES)',
    null,
    '(ALL)',
    round(avg(tot_on_time_rate), 2),
    round(avg(tot_slight_dly_rate), 2),
    round(avg(tot_moderate_dly_rate), 2),
    round(avg(tot_substantial_dly_rate), 2),
    round(avg(tot_severe_dly_rate), 2),
    round(avg(avg_tot_delay_minutes), 2),
    round(avg(max_tot_delay_minutes), 2),
    min(om.model)
from tot_percentages, overall_most_used_aircraft_model om

order by phase, on_time_rate_pct desc, severe_dly_rate_pct;