import pandas_gbq
from google.oauth2 import service_account

# 1. Load credentials once
credentials = service_account.Credentials.from_service_account_file(
    '../mean_mug_analytics/mean-mug-analytics-7f3a37898649.json' 
)
project_id = 'mean-mug-analytics'

# 2. Build the reusable upload function
def push_to_warehouse(df, table_name):
    print(f"Uploading {table_name} to BigQuery...")
    table_id = f'{project_id}.mean_mug_marts.{table_name}'
    
    pandas_gbq.to_gbq(
        df,
        destination_table=table_id,
        project_id=project_id,
        credentials=credentials,
        if_exists='replace'
    )
    print(f"Success: {table_name} is live!")
