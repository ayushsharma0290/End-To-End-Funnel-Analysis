"""
Run once:  python python/02_extract_and_load.py   (from project root folder)
Needs:     pip install pandas pandas-gbq sqlalchemy pymysql db-dtypes
Steps:     BigQuery (flatten query) -> pandas -> CSV backup -> MySQL
First run opens a browser for Google login (use the same Gmail as BigQuery).
Run sql/02_mysql_schema.sql in Workbench BEFORE this script.
"""
import pandas as pd, pandas_gbq
from sqlalchemy import create_engine
from urllib.parse import quote_plus

PROJECT_ID = "your-gcp-project-id"   # <- your GCP project id (left panel in BigQuery)
MYSQL_USER, MYSQL_PWD = "YOUR_SQL_USERNAME", "YOUR_SQL_PASSWORD"

sql = open("sql/01_bigquery_flatten.sql").read()
df = pandas_gbq.read_gbq(sql, project_id=PROJECT_ID)
print("Rows pulled:", len(df))

df = df.drop_duplicates("session_id")             # GA sample has a few duplicate ids
df["session_date"] = pd.to_datetime(df["session_date"])
df.to_csv("data/sessions_raw.csv", index=False)   # backup (add data/ to .gitignore)

engine = create_engine(f"mysql+pymysql://{MYSQL_USER}:{quote_plus(MYSQL_PWD)}@localhost:3306/funnel_analysis")
df.to_sql("sessions", engine, if_exists="append", index=False, chunksize=20000, method="multi")
print("Loaded into MySQL:", len(df))
