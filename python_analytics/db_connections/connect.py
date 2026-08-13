import duckdb
import os
import numpy
import pandas

def get_warehouse_connection(db_path='mean_mug.duckdb'):
    """
    Establishes and returns a read/write connection to the DuckDB data warehouse.
    
    Args:
        db_path (str): The relative or absolute path to your .duckdb file.
    """
    # Verify the file actually exists before trying to connect
    # If you tell it to connect to a database file that doesn't exist, it doesn't throw an error. It just creates a new, empty database with that name.
    if not os.path.exists(db_path):
        raise FileNotFoundError(f"Could not find the database at {db_path}. Check your path!")
    
    # Connect with read_only=False so we can write our pandas DataFrames back to the warehouse
    con = duckdb.connect(database=db_path, read_only=False)
    print(f"Successfully connected to warehouse: {db_path}")
    
    return con


# This block only runs if you execute this specific file directly.
# It acts as a quick health check for your connection.
if __name__ == "__main__":
    test_con = get_warehouse_connection('mean_mug_analytics/mean_mug.duckdb')
    tables = test_con.execute("SHOW TABLES;").df()
    print("\nAvailable tables in warehouse:")
    print(tables)
    
    test_con.close()