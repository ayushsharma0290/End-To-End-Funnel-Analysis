CREATE DATABASE IF NOT EXISTS funnel_analysis;
USE funnel_analysis;

DROP TABLE IF EXISTS sessions;
CREATE TABLE sessions (
  session_id    VARCHAR(40),
  visitor_id    VARCHAR(30),
  session_date  DATE,
  hour_utc      TINYINT,
  device        VARCHAR(15),
  os            VARCHAR(40),
  country       VARCHAR(70),
  city          VARCHAR(90),
  user_type     VARCHAR(10),
  channel       VARCHAR(30),
  source        VARCHAR(90),
  pageviews     INT,
  time_on_site  INT,
  product_view  TINYINT,
  add_to_cart   TINYINT,
  checkout      TINYINT,
  purchase      TINYINT,
  revenue       DECIMAL(12,2),
  first_pv_sec  DECIMAL(10,1),
  purchase_sec  DECIMAL(10,1),
  INDEX idx_date (session_date),
  INDEX idx_device (device),
  INDEX idx_country (country),
  INDEX idx_user (user_type),
  INDEX idx_channel (channel)
);
