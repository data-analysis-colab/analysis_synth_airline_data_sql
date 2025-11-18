# Detailed Documentation: Capacity Demand and Utilization Analysis

## Objective

This analysis examines how overall demand (percentage of seats booked) and actual capacity utilization 
(percentage of seats occupied after check-in) vary across different flight and passenger characteristics. 
Specifically, it investigates the impact of:

- Flight distance category
- Departure and arrival countries and airports
- Day of the week, travel season, and holidays
- Available passenger classes

Additionally, it:

- Divides routes into performance tiers and evaluates consistency in tier sizes and average booking rates across 
  seasons and weekdays
- Identifies the top- and bottom-performing routes overall

## Terminology and Methodology

Each query includes its own comment block. The following notes summarize key definitions and procedures that 
apply across multiple queries:

- **Booked Rate** (`bookings / capacity * 100`)  
Calculated in CTEs that include flights later canceled, since their bookings still indicate demand.
- **Occupancy Rate** (`checked-in passengers / capacity * 100`)  
Reflects actual seat utilization and includes only non-canceled flights.
- **Check-In Gap**  
The average difference between booked and occupied seats, representing the share of passengers who did not check 
in or missed their flight.
- **Country and Airport Metrics**  
Demand and occupancy by country or airport are derived through separate CTE chains for departures and arrivals. 
Combined metrics are computed as true weighted averages normalized by flight count. While this is redundant for the 
simulated dataset (which ensures balanced departures and arrivals per day), it mirrors best practices for 
real-world data analysis.
- **Performance Tiers**  
Routes are classified into the following categories based on their average booked rate:
  
  | Tier | Label           | Booked Rate Range |
  |------|-----------------|-------------------|
  | A    | Top Performance | /> 85%            |
  | B    | Within Target   | 76–85%            |
  | C    | Sufficient      | 70–75%            |
  | D    | Underperforming | < 70%             |
  | E    | Unsustainable   | < 60%             |

## Key Insights and Visualizations

- **Demand vs. Capacity Trends**  
Long-haul routes, long-haul-only airports, and first-class seats achieve the highest booked and occupancy rates.
Short-haul routes and economy class show the lowest rates.
This pattern indicates efficient alignment between high-cost capacities and high-demand segments.

- **Temporal Patterns**  

  - Best-performing weekdays: Friday and Sunday
  - Lowest-performing weekdays: Tuesday and Saturday
  - Strongest travel seasons: Summer and December (winter holidays)
  - Weakest seasons: January/February and autumn

  These trends align with typical travel behavior patterns.

- **Route Performance Distribution**

  - ~65% of routes meet or exceed the target booked rate (76–85%) and are expected to be profitable.
  (See profitability analysis [here](../(C)_revenue_and_profit/REVENUE_AND_PROFIT.md).)
  - ~31% of routes maintain sufficient utilization (70–75%), likely breaking even.
  - ~4% (six routes total) are underperforming (< 70%).

- **Check-In Gaps**  
Smaller check-in gaps are observed for high-demand flights, particularly long-haul routes, peak weekdays, 
and first-class seats.

- **Route Type Consistency**  
The top-performing routes (long-haul) and bottom-performing routes (short-haul) remain consistent across both 
weekday and seasonal breakdowns.

  - [Top/Bottom Routes by Season (EN)](../visualizations/english/(03)_booked_rate_tb_routes_seasons.png)
    - [German: Stärkste/Schwächste Routen nach Reisezeitraum](../visualizations/german/(03)_buchungsrate_tf_routen_reisezeit.png)
  - [Top/Bottom Routes by Weekday Group (EN)](../visualizations/english/(05)_booked_rate_tb_routes_weekdays.png)
    - [German: Stärkste/Schwächste Routen nach Wochentagsgruppe](../visualizations/german/(05)_buchungsrate_tf_routen_wochentage.png)

- **Weekday Trends by Performance Tier**  
Performance fluctuations across weekdays follow nearly identical patterns for all tiers.
  - [Weekday Booking Trends (EN)](../visualizations/english/(04)_booked_rate_routes_weekdays_lineplot.png)
    - [German: Buchungstrends nach Routenleistungsstufe](../visualizations/german/(04)_buchungsrate_routen_wochentage_lineplot.png)

- **Performance by Passenger Class**

  - The first-class segments for all routes fall into the top tier (> 85%).
  - Business class performances span the top two tiers (> 76%).
  - Economy class primarily occupies the “Sufficient” tier (70–75%).
  - All underperforming routes (< 70%) are driven by underutilized economy-capacity.
  - [Route-Class Heatmap (EN)](../visualizations/english/(06)_route_classes_heatmap.png)
    - [German: Routen-Leistung nach Klassen](../visualizations/german/(06)_routen_klassen_heatmap.png)

- **Seasonal Performance Stability**  
Across all tiers, summer and December consistently yield the highest booked rates, while January–February 
and autumn remain the weakest.
  - [Global Tiers by Season (EN)](../visualizations/english/(02a)_booked_rate_routes_seasons_heatmap.png)
    - [German: Globale Leistungsstufen nach Reisezeit](../visualizations/german/(02a)_buchungsrate_routen_reisezeiten_heatmap.png)

- **Hybrid Tier Intersections**  
Combining global and seasonal tier classifications helps detect potential seasonal outliers.
Most routes remain within one tier level across all seasons (e.g., global A-tier routes also fall 
into seasonal a/b tiers).
The main exception involves 22 routes that perform within target (B-tier) globally but drop to d-tier in 
January/February.
This likely reflects seasonal data segmentation – December’s strong performance being separated from the weaker 
January/February months.
<img src="../visualizations/english/(02b)_route_count_booked_rate_heatmap.png" alt="Hybrid Tiers by Season (EN)" width="65%">

  - [German: Hybride Leistungsstufen nach Reisezeit](../visualizations/german/(02b)_routen_anzahl_buchungsrate_reisezeiten_heatmap.png)
