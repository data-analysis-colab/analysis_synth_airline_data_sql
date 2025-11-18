/*
--------------------------------------------------------------------------------------------------------
View: hazardous_weather_constellations
--------------------------------------------------------------------------------------------------------
Defines all relevant hazardous weather constellations for *departure delays* and *cancellations*.

Each observation is classified by combinations of weather hazard flags
(Fog, Blizzard, Sandstorm, Visibility <1 km, Wind >70 km/h, Extreme Cold/Heat).

"Fog only" is a special case marking conditions where visibility is not yet below 1 km,
but a delay is triggered due to the imminent risk of deterioration.

Used in:
    - Departure delay and cancellation logic
    - `weather_delay_obs` CTE in the weather delay constellation analysis
--------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------
View: hazardous_weather_const_arr_dly
--------------------------------------------------------------------------------------------------------
Defines hazardous weather constellations relevant for *arrival delays*.

This version includes only the weather dimensions that impact landing feasibility:
(Fog, Blizzard, Sandstorm, Visibility <1 km, Wind >70 km/h).

Used exclusively for:
    - Arrival delay logic in `weather_delay_obs` (main weather delay constellation query)
--------------------------------------------------------------------------------------------------------
*/

create or replace view hazardous_weather_constellations as
    with hazard_flags as (
        select
            airport_code,
            observation_time,
            case when condition_description = 'Fog' then 1 else 0 end as fog,
            case when condition_description = 'Blizzard' then 1 else 0 end as blizzard,
            case when condition_description = 'Sandstorm' then 1 else 0 end as sandstorm,
            case when visibility_km < 1.0 then 1 else 0 end as visibility,
            case when wind_speed_kmh > 70.0 then 1 else 0 end as wind,
            case when temperature_celsius < -25.0 then 1 else 0 end as extreme_cold,
            case when temperature_celsius > 45.0 then 1 else 0 end as extreme_heat
        from weather
    )
    select
        airport_code,
        observation_time,
        fog, blizzard, sandstorm, visibility, wind, extreme_cold, extreme_heat,
        case

            when fog = 1 and visibility = 0 and wind = 0 and extreme_cold = 0 and extreme_heat = 0
                then 'Fog only'
            when fog = 1 and visibility = 1 and wind = 0 and extreme_cold = 0 and extreme_heat = 0
                then 'Fog, Visibility'
            when fog = 1 and visibility = 0 and wind = 0 and extreme_cold = 1 and extreme_heat = 0
                then 'Fog, Low_temp'
            when fog = 1 and visibility = 1 and wind = 0 and extreme_cold = 1 and extreme_heat = 0
                then 'Fog, Visibility, Low_temp'

            when blizzard = 1 and visibility = 0 and wind = 0 and extreme_cold = 0 and extreme_heat = 0
                then 'Blizzard only'
            when blizzard = 1 and visibility = 1 and wind = 0 and extreme_cold = 0 and extreme_heat = 0
                then 'Blizzard, Visibility'
            when blizzard = 1 and visibility = 0 and wind = 1 and extreme_cold = 0 and extreme_heat = 0
                then 'Blizzard, Wind'
            when blizzard = 1 and visibility = 0 and wind = 0 and extreme_cold = 1 and extreme_heat = 0
                then 'Blizzard, Low_temp'
            when blizzard = 1 and visibility = 1 and wind = 1 and extreme_cold = 0 and extreme_heat = 0
                then 'Blizzard, Visibility, Wind'
            when blizzard = 1 and visibility = 1 and wind = 0 and extreme_cold = 1 and extreme_heat = 0
                then 'Blizzard, Visibility, Low_temp'
            when blizzard = 1 and visibility = 0 and wind = 1 and extreme_cold = 1 and extreme_heat = 0
                then 'Blizzard, Wind, Low-temp'
            when blizzard = 1 and visibility = 1 and wind = 1 and extreme_cold = 1 and extreme_heat = 0
                then 'Blizzard, Visibility, Wind, Low_temp'

            when sandstorm = 1 and visibility = 0 and wind = 0 and extreme_cold = 0 and extreme_heat = 0
                then 'Sandstorm only'
            when sandstorm = 1 and visibility = 1 and wind = 0 and extreme_cold = 0 and extreme_heat = 0
                then 'Sandstorm, Visibility'
            when sandstorm = 1 and visibility = 0 and wind = 1 and extreme_cold = 0 and extreme_heat = 0
                then 'Sandstorm, Wind'
            when sandstorm = 1 and visibility = 0 and wind = 0 and extreme_cold = 0 and extreme_heat = 1
                then 'Sandstorm, High_temp'
            when sandstorm = 1 and visibility = 1 and wind = 1 and extreme_cold = 0 and extreme_heat = 0
                then 'Sandstorm, Visibility, Wind'
            when sandstorm = 1 and visibility = 1 and wind = 0 and extreme_cold = 0 and extreme_heat = 1
                then 'Sandstorm, Visibility, High_temp'
            when sandstorm = 1 and visibility = 0 and wind = 1 and extreme_cold = 0 and extreme_heat = 1
                then 'Sandstorm, Wind, High_temp'
            when sandstorm = 1 and visibility = 1 and wind = 1 and extreme_cold = 0 and extreme_heat = 1
                then 'Sandstorm, Visibility, Wind, High_temp'

            when fog = 0 and blizzard = 0 and sandstorm = 0 and
                 visibility = 1 and wind = 0 and extreme_cold = 0 and extreme_heat = 0
                then 'Visibility only'
            when fog = 0 and blizzard = 0 and sandstorm = 0 and
                 visibility = 1 and wind = 1 and extreme_cold = 0 and extreme_heat = 0
                then 'Visibility, Wind'
            when fog = 0 and blizzard = 0 and sandstorm = 0 and
                 visibility = 1 and wind = 0 and extreme_cold = 1 and extreme_heat = 0
                then 'Visibility, Low_temp'
            when fog = 0 and blizzard = 0 and sandstorm = 0 and
                 visibility = 1 and wind = 0 and extreme_cold = 0 and extreme_heat = 1
                then 'Visibility, High_temp'
            when fog = 0 and blizzard = 0 and sandstorm = 0 and
                 visibility = 1 and wind = 1 and extreme_cold = 1 and extreme_heat = 0
                then 'Visibility, Wind, Low_temp'
            when fog = 0 and blizzard = 0 and sandstorm = 0 and
                 visibility = 1 and wind = 1 and extreme_cold = 0 and extreme_heat = 1
                then 'Visibility, Wind, High_temp'

            when fog = 0 and blizzard = 0 and sandstorm = 0 and
                 visibility = 0 and wind = 1 and extreme_cold = 0 and extreme_heat = 0
                then 'Wind only'
            when fog = 0 and blizzard = 0 and sandstorm = 0 and
                 visibility = 0 and wind = 1 and extreme_cold = 1 and extreme_heat = 0
                then 'Wind, Low_temp'
            when fog = 0 and blizzard = 0 and sandstorm = 0 and
                 visibility = 0 and wind = 1 and extreme_cold = 0 and extreme_heat = 1
                then 'Wind, High_temp'

            when fog = 0 and blizzard = 0 and sandstorm = 0 and
                 visibility = 0 and wind = 0 and extreme_cold = 1 and extreme_heat = 0
                then 'Low_temp only'
            when fog = 0 and blizzard = 0 and sandstorm = 0 and
                 visibility = 0 and wind = 0 and extreme_cold = 0 and extreme_heat = 1
                then 'High_temp only'

        end as constellation
    from hazard_flags
    where fog + blizzard + sandstorm + visibility + wind + extreme_cold + extreme_heat > 0;



create or replace view hazardous_weather_const_arr_dly as
    with hazard_flags as (
        select
            airport_code,
            observation_time,
            case when condition_description = 'Fog' then 1 else 0 end as fog,
            case when condition_description = 'Blizzard' then 1 else 0 end as blizzard,
            case when condition_description = 'Sandstorm' then 1 else 0 end as sandstorm,
            case when visibility_km < 1.0 then 1 else 0 end as visibility,
            case when wind_speed_kmh > 70.0 then 1 else 0 end as wind
        from weather
    )
    select
        airport_code,
        observation_time,
        fog, blizzard, sandstorm, visibility, wind,
        case

            when fog = 1 and visibility = 0 and wind = 0
                then 'Fog only'
            when fog = 1 and visibility = 1 and wind = 0
                then 'Fog, Visibility'

            when blizzard = 1 and visibility = 0 and wind = 0
                then 'Blizzard only'
            when blizzard = 1 and visibility = 1 and wind = 0
                then 'Blizzard, Visibility'
            when blizzard = 1 and visibility = 0 and wind = 1
                then 'Blizzard, Wind'
            when blizzard = 1 and visibility = 1 and wind = 1
                then 'Blizzard, Visibility, Wind'

            when sandstorm = 1 and visibility = 0 and wind = 0
                then 'Sandstorm only'
            when sandstorm = 1 and visibility = 1 and wind = 0
                then 'Sandstorm, Visibility'
            when sandstorm = 1 and visibility = 0 and wind = 1
                then 'Sandstorm, Wind'
            when sandstorm = 1 and visibility = 1 and wind = 1
                then 'Sandstorm, Visibility, Wind'

            when fog = 0 and blizzard = 0 and sandstorm = 0 and
                 visibility = 1 and wind = 0
                then 'Visibility only'
            when fog = 0 and blizzard = 0 and sandstorm = 0 and
                 visibility = 1 and wind = 1
                then 'Visibility, Wind'

            when fog = 0 and blizzard = 0 and sandstorm = 0 and
                 visibility = 0 and wind = 1
                then 'Wind only'

        end as constellation
    from hazard_flags
    where fog + blizzard + sandstorm + visibility + wind > 0;