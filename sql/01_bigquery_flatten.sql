
-- Engine: BigQuery (Standard SQL), not MySQL. Run in the BigQuery console or via python/02_extract_and_load.py
-- Goal: flatten nested GA data into one row per session with funnel flags
-- Period: 1 Aug 2016 to 31 Jul 2017 (full year, to capture seasonality and the holiday period)
-- Tip: narrow _TABLE_SUFFIX (for example '20170101' to '20170331') for a smaller sample

SELECT
  CONCAT(fullVisitorId, '-', CAST(visitId AS STRING))       AS session_id,
  fullVisitorId                                              AS visitor_id,
  PARSE_DATE('%Y%m%d', date)                                 AS session_date,
  EXTRACT(HOUR FROM TIMESTAMP_SECONDS(visitStartTime))       AS hour_utc,
  device.deviceCategory                                      AS device,
  device.operatingSystem                                     AS os,
  geoNetwork.country                                         AS country,
  geoNetwork.city                                            AS city,
  IF(totals.newVisits = 1, 'New', 'Returning')               AS user_type,
  channelGrouping                                            AS channel,
  trafficSource.source                                       AS source,
  IFNULL(totals.pageviews, 0)                                AS pageviews,
  IFNULL(totals.timeOnSite, 0)                               AS time_on_site,

  -- funnel flags: 1 if the session had that eCommerce action at least once
  (SELECT MAX(IF(h.eCommerceAction.action_type = '2', 1, 0)) FROM UNNEST(hits) h) AS product_view,
  (SELECT MAX(IF(h.eCommerceAction.action_type = '3', 1, 0)) FROM UNNEST(hits) h) AS add_to_cart,
  (SELECT MAX(IF(h.eCommerceAction.action_type = '5', 1, 0)) FROM UNNEST(hits) h) AS checkout,
  (SELECT MAX(IF(h.eCommerceAction.action_type = '6', 1, 0)) FROM UNNEST(hits) h) AS purchase,

  IFNULL(totals.totalTransactionRevenue, 0) / 1000000        AS revenue,   -- micros -> $

  -- time-to-convert (seconds from session start; h.time is in ms)
  (SELECT MIN(IF(h.eCommerceAction.action_type = '2', h.time, NULL)) FROM UNNEST(hits) h) / 1000 AS first_pv_sec,
  (SELECT MIN(IF(h.eCommerceAction.action_type = '6', h.time, NULL)) FROM UNNEST(hits) h) / 1000 AS purchase_sec
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_*`
WHERE _TABLE_SUFFIX BETWEEN '20160801' AND '20170731';
