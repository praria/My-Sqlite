# Welcome to My Sqlite
***********************

Mysqlite is a basic Sqlite-like database system application build with the implementation of a command line interface (CLI) and corresponding requests handling.



## Task
This application consists of two main components.
1. class MySqliteRequest in my_sqlite_request.rb
   - This component handles creation and execution of various SQL-like requests, including SELECT, INSERT, UPDATE, DELETE and JOIN Operations.
2. The command line interface my_sqlite_cli.rb that interact with my_sqlite_request.rb
    - This component allows users to interact with a CSV-based databse by entering SQL-like queries.


## Description 
Features included:
SELECT Operation: 
    -This operation retrieves and display data from the csv file with various filtering conditions and JOIN oparations.

INSERT Operation:
    -This operation inserts new records into csv file.

UPDATE Operation:
    -This operation modifies the existing records in csv file based on specified conditions.

DELECT Operation:
    -This operation deletes records from csv file based on specified conditions.

JOIN Operation:
    This operation combines data from two csv files based on specified condtions.


Request Construction - Problems/ Challenges and Solutions:
************************************************************
The 'MySqliteRequest' class in 'my_sqlite_request.rb' overcomes challenges associated with parsing SQL queries and handling dynamic csv file structures. 
It offers usesrs a flexible and powerful tool for interacting with csv-based databases by providing a set of methods for users to construct different types of following requests.

1. SELECT Request: THE 'select(column_name)', from(table_name) and where(column_name, criteria) methods construct a SELECT request with specified columns
2. INSERT Request: The 'insert(table_name)' and 'values(data)' methods construct an INSERT request with the given table name and data.
3. UPDATE Request: The 'update(table_name)' , 'set(data)' and where(column_name, criteria) methods construct an UPDATE request with table name, set values and WHERE conditions.
4. DELETE Request: The 'delete', 'from(table_name)' and 'where(column_name, criteria)' methods construct a DELECT request with the table name and WHERE conditions. 
5. JOIN Request: The 'from(main_table_name)', 'join(column_on_db_a, filename_db_b, column_on_db_b)' methods construct a JOIN Request with the main table name, JOIN conditions and secondary table name.

     
Command-Line Interface Construction - Problems/ Challenges and Solutions::
*************************************************************************** 
Designing a user-friendly CLI that interprets SQL-like syntax and provides meaningful response to users was a key challenge. One of the challenges was parsing SQL-Like queries entered through 
the CLI. The queries needed to be broken down into essential components, such as table names, set values, WHERE conditions, and JOIN conditions. Regular expressions were employed to extract relevant information from the queries. Multiple regex
patterns were designed to handle different parts of SQL queries, ensuring flexibility and accuracy. 


## Installation
Ruby Installation on the system 
Ruby's CSV library

## Usage
Run REQUEST:
-Execute 'ruby my_sqlite_request.rb' in the terminal in order to run different requests defined within def _main() methods inside 'my_sqlite_request.rb'.
For referece: Use 'request_queries_for_request_testing.txt' for various ready-made requests or testcases. 

    SELECT Request - Usage Example:
    ******************************
    request = MySqliteRequest.new
    request = request.from('nba_player_data_light.csv')
    request = request.select(['name', 'college'])
    result  = request.run 
    p result
     
Run CLI: 
-Execute 'ruby my_sqlite_cli.rb' in the terminal to start mysqlite CLI. Enter SQL-Like queries such a SELECT, INSERT, UPDATE, DELETE, OR JOIN, to interact with csv-based database
and display the results of the queries in order to analyze and manipulate the data.
For reference: Use 'sql_queries_for_cli_testing.txt' for using various ready-made sql-like queries. 

    SELECT CLI Query - Usage Example:
    ********************************
    my_sqlite_query_cli> SELECT name FROM nba_player_data_light.csv ORDER BY name DESC;


### The Core Team 
-- Sol -- Prakash Shrestha --


<span><i>Made at <a href='https://qwasar.io'>Qwasar SV -- Software Engineering School</a></i></span>
<span><img alt='Qwasar SV -- Software Engineering School's Logo' src='https://storage.googleapis.com/qwasar-public/qwasar-logo_50x50.png' width='20px' /></span>
