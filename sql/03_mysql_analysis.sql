
USE funnel_analysis;

-- Q0: sanity checks
SELECT COUNT(*) AS sessions, MIN(session_date) AS first_day, MAX(session_date) AS last_day FROM sessions;
SELECT SUM(product_view) pv, SUM(add_to_cart) atc, SUM(checkout) co, SUM(purchase) pu FROM sessions;

-- Q1: OVERALL FUNNEL + step conversion + drop-off
WITH f AS (
  SELECT COUNT(*) visits, SUM(product_view) pv, SUM(add_to_cart) atc,
         SUM(checkout) co, SUM(purchase) pu
  FROM sessions)
SELECT 'Visit'        AS stage, visits AS sessions, NULL AS step_conv_pct, NULL AS drop_pct FROM f
UNION ALL SELECT 'Product view', pv,  ROUND(100*pv/visits,2),  ROUND(100-100*pv/visits,2)  FROM f
UNION ALL SELECT 'Add to cart',  atc, ROUND(100*atc/pv,2),     ROUND(100-100*atc/pv,2)     FROM f
UNION ALL SELECT 'Checkout',     co,  ROUND(100*co/atc,2),     ROUND(100-100*co/atc,2)     FROM f
UNION ALL SELECT 'Purchase',     pu,  ROUND(100*pu/co,2),      ROUND(100-100*pu/co,2)      FROM f;

-- Q2: STRICT funnel (user must pass every previous stage)
SELECT COUNT(*) visits,
  SUM(product_view) pv,
  SUM(product_view AND add_to_cart) atc_strict,
  SUM(product_view AND add_to_cart AND checkout) co_strict,
  SUM(product_view AND add_to_cart AND checkout AND purchase) pu_strict
FROM sessions;

-- Q3: SEGMENT BY DEVICE 
SELECT device, COUNT(*) visits, SUM(product_view) pv, SUM(add_to_cart) atc, SUM(checkout) co, SUM(purchase) pu,
  ROUND(100*SUM(product_view)/COUNT(*),2)            AS visit_to_pv,
  ROUND(100*SUM(add_to_cart)/SUM(product_view),2)    AS pv_to_atc,
  ROUND(100*SUM(checkout)/SUM(add_to_cart),2)        AS atc_to_co,
  ROUND(100*SUM(purchase)/SUM(checkout),2)           AS co_to_pu,
  ROUND(100*SUM(purchase)/COUNT(*),2)                AS overall_conv
FROM sessions GROUP BY device ORDER BY visits DESC;

-- Q4: SEGMENT BY USER TYPE (new vs returning) 
SELECT user_type, COUNT(*) visits, SUM(product_view) pv, SUM(add_to_cart) atc, SUM(checkout) co, SUM(purchase) pu,
  ROUND(100*SUM(product_view)/COUNT(*),2)            AS visit_to_pv,
  ROUND(100*SUM(add_to_cart)/SUM(product_view),2)    AS pv_to_atc,
  ROUND(100*SUM(checkout)/SUM(add_to_cart),2)        AS atc_to_co,
  ROUND(100*SUM(purchase)/SUM(checkout),2)           AS co_to_pu,
  ROUND(100*SUM(purchase)/COUNT(*),2)                AS overall_conv
FROM sessions GROUP BY user_type;

-- Q5: SEGMENT BY LOCATION (top countries, min 1000 visits)
SELECT country, COUNT(*) visits, SUM(purchase) pu,
  ROUND(100*SUM(product_view)/COUNT(*),2)            AS visit_to_pv,
  ROUND(100*SUM(add_to_cart)/SUM(product_view),2)    AS pv_to_atc,
  ROUND(100*SUM(checkout)/SUM(add_to_cart),2)        AS atc_to_co,
  ROUND(100*SUM(purchase)/SUM(checkout),2)           AS co_to_pu,
  ROUND(100*SUM(purchase)/COUNT(*),2)                AS overall_conv
FROM sessions GROUP BY country HAVING visits >= 1000 ORDER BY visits DESC LIMIT 15;

-- Q5b: top cities inside the United States 
SELECT city, COUNT(*) visits, SUM(purchase) pu, ROUND(100*SUM(purchase)/COUNT(*),2) AS overall_conv
FROM sessions WHERE country='United States' AND city NOT LIKE '%not available%'
GROUP BY city HAVING visits >= 1000 ORDER BY visits DESC LIMIT 10;

-- Q6: SEGMENT BY TRAFFIC CHANNEL (bonus) 
SELECT channel, COUNT(*) visits, SUM(purchase) pu,
  ROUND(100*SUM(product_view)/COUNT(*),2)            AS visit_to_pv,
  ROUND(100*SUM(add_to_cart)/SUM(product_view),2)    AS pv_to_atc,
  ROUND(100*SUM(checkout)/SUM(add_to_cart),2)        AS atc_to_co,
  ROUND(100*SUM(purchase)/SUM(checkout),2)           AS co_to_pu,
  ROUND(100*SUM(purchase)/COUNT(*),2)                AS overall_conv
FROM sessions GROUP BY channel ORDER BY visits DESC;

-- Q7: CROSS-SEGMENT: device x user_type (finds hidden problem pockets)
SELECT device, user_type, COUNT(*) visits, SUM(checkout) co, SUM(purchase) pu,
  ROUND(100*SUM(purchase)/SUM(checkout),2) AS co_to_pu,
  ROUND(100*SUM(purchase)/COUNT(*),2)      AS overall_conv
FROM sessions GROUP BY device, user_type ORDER BY device, user_type;

-- Q8: LOST REVENUE if mobile checkout->purchase matched desktop
WITH d AS (
  SELECT device, SUM(checkout) co, SUM(purchase) pu, SUM(revenue) rev FROM sessions GROUP BY device),
aov AS (SELECT SUM(revenue)/SUM(purchase) AS aov FROM sessions WHERE purchase=1)
SELECT m.co AS mobile_checkouts, m.pu AS mobile_purchases,
  ROUND(m.co * dk.pu/dk.co) AS purchases_if_desktop_rate,
  ROUND(m.co * dk.pu/dk.co) - m.pu AS extra_purchases,
  ROUND((m.co * dk.pu/dk.co - m.pu) * aov.aov, 0) AS extra_revenue_usd,
  ROUND(aov.aov,2) AS aov
FROM d m JOIN d dk ON dk.device='desktop' CROSS JOIN aov WHERE m.device='mobile';

-- TIME-BASED ANALYSIS --

-- Q9: Monthly trend
SELECT DATE_FORMAT(session_date,'%Y-%m') AS month, COUNT(*) visits,
  SUM(add_to_cart) atc, SUM(checkout) co, SUM(purchase) pu,
  ROUND(100*SUM(add_to_cart)/SUM(product_view),2) AS pv_to_atc,
  ROUND(100*SUM(purchase)/SUM(checkout),2)        AS co_to_pu,
  ROUND(100*SUM(purchase)/COUNT(*),2)             AS overall_conv,
  ROUND(SUM(revenue),0) AS revenue
FROM sessions GROUP BY month ORDER BY month;

-- Q10: Weekly trend (WoW change with window function)
WITH w AS (
  SELECT YEARWEEK(session_date,1) AS yw, MIN(session_date) AS week_start, COUNT(*) visits,
         ROUND(100*SUM(purchase)/COUNT(*),2) AS conv
  FROM sessions GROUP BY yw)
SELECT week_start, visits, conv,
       ROUND(conv - LAG(conv) OVER (ORDER BY yw),2) AS wow_change_pp
FROM w ORDER BY yw;

-- Q11: Day of week (1=Sun ... 7=Sat)
SELECT DAYOFWEEK(session_date) AS dow, DAYNAME(session_date) AS day_name, COUNT(*) visits,
  ROUND(100*SUM(purchase)/SUM(checkout),2) AS co_to_pu,
  ROUND(100*SUM(purchase)/COUNT(*),2)      AS overall_conv
FROM sessions GROUP BY dow, day_name ORDER BY dow;

-- Q12: Weekday vs weekend, split by device
SELECT IF(DAYOFWEEK(session_date) IN (1,7),'Weekend','Weekday') AS day_type, device,
  COUNT(*) visits, ROUND(100*SUM(purchase)/COUNT(*),2) AS overall_conv
FROM sessions GROUP BY day_type, device ORDER BY device, day_type;

-- Q13: Hour of day (UTC)
SELECT hour_utc, COUNT(*) visits, SUM(purchase) pu,
  ROUND(100*SUM(purchase)/COUNT(*),2) AS overall_conv
FROM sessions GROUP BY hour_utc ORDER BY hour_utc;

-- Q14: Heatmap data: day x hour (use in Power BI matrix)
SELECT DAYOFWEEK(session_date) AS dow, hour_utc, COUNT(*) visits,
  ROUND(100*SUM(purchase)/COUNT(*),2) AS overall_conv
FROM sessions GROUP BY dow, hour_utc HAVING visits >= 200 ORDER BY dow, hour_utc;

-- Q15: Seasonality: holiday window (Nov 15 - Dec 31, 2016) vs rest
SELECT IF(session_date BETWEEN '2016-11-15' AND '2016-12-31','Holiday season','Other') AS period,
  COUNT(*) visits, ROUND(100*SUM(add_to_cart)/SUM(product_view),2) AS pv_to_atc,
  ROUND(100*SUM(purchase)/SUM(checkout),2) AS co_to_pu,
  ROUND(100*SUM(purchase)/COUNT(*),2) AS overall_conv
FROM sessions GROUP BY period;

-- Q16: Time-to-convert inside session (minutes, product view -> purchase)
SELECT COUNT(*) buyers,
  ROUND(AVG(purchase_sec - first_pv_sec)/60,1) AS avg_minutes
FROM sessions WHERE purchase=1 AND first_pv_sec IS NOT NULL AND purchase_sec >= first_pv_sec;

-- Q17: Mobile checkout leak trend by month (getting better or worse?)
SELECT DATE_FORMAT(session_date,'%Y-%m') AS month, device,
  SUM(checkout) co, SUM(purchase) pu, ROUND(100*SUM(purchase)/SUM(checkout),2) AS co_to_pu
FROM sessions WHERE device IN ('mobile','desktop')
GROUP BY month, device ORDER BY month, device;
