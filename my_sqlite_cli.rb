require "readline"
require_relative "my_sqlite_request" 


class MySqliteCli 
    def initialize(database_file)
        @request = nil
        @database_file = database_file 
    end 

    def start 
        puts "MySQLite version 0.1 #{Time.now.strftime('%Y-%m-%d')}"
        @request = MySqliteRequest.new 

        loop do 
            # puts "Before Readline.readline "
            input = Readline.readline( "my_sqlite_query_cli> ", true)
            # puts "After Readline.readline: #{input}"
            break if input.downcase == 'quit'

            process_input(input)
        end 
    end     

    private 

    def process_input(input)
        # initialize @request before processing each input  
        @request = MySqliteRequest.new 
         
        case input.strip.downcase 
        when /^select.*from.*join.*on.*$/i
            process_join(input) 
        when /^select.*from.*$/
            process_select(input)
        when /^insert into.*values.*$/ 
            process_insert(input) 
        when /^update.*set.*where.*$/ 
            process_update(input) 
        when /^delete from.*where.*$/ 
            process_delete(input)
        else 
            puts "Invalid command: #{input}"
        end 
    end 

    def process_select(input)
        # extract the table name
        table_name_match = input.match(/from\s+(\w+\.?\w+)/i)
        table_name = table_name_match[1] if table_name_match 

        # Extract the list of columns from the input string 
        column_match = input.match(/^select\s+(.+?)\s+from\s+(\w+\.?\w+)/i) 

        if column_match 
            columns = column_match[1].split(',').map(&:strip) 
            table_name = column_match[2] 

            # Initialize MySqliteRequest @request and setting up 'from' clause before calling run 
            # @request.from(table_name).select(columns) 
            @request.from(table_name) 
            @request.select(columns)
            
            # extract conditions from the WHERE clause (if present)
            where_match = input.match(/where\s+(.+)$/i)
            where_conditions = Hash[where_match[1].scan(/(\w+)\s*=\s*'(.+?)'/)] if where_match 
            # initialize an empty hash if where_conditions is nil 
            where_conditions ||= {} 
            # initializing @request and setting up 'where' clause before calling run
            @request.where(where_conditions) if where_conditions 
            
            # to ensure @select_columns is set appropriately 
            @select_columns = @request.instance_variable_get(:@select_columns)
        else 
            puts "Invalid SELECT statement. Please provide valid SELECT syntax" 
            return 
        end 

        # extract order by clause 
        order_by_match = input.match(/order\s+by\s+(\w+)\s*(asc|desc)?/i) 
        if order_by_match 
            order_by_column = order_by_match[1] 
            order_direction = order_by_match[2]&.downcase&.to_sym || :asc 
            @request.order(order_direction, order_by_column) 
        end 
        
        # run the select statement
        result = @request.run 
        # puts "Debug: Result from process_select in CLI - #{result.inspect}"

        # display the result 
        display_result(result)         
    end 


    def process_insert(input) 
        # extracting table_name 
        table_name_match = input.match(/into\s+['"]?(\w+\.\w+)['"]?\s+values/i) 
        table_name = table_name_match[1] if table_name_match 

        # puts "Debug: input data is: #{input}" 
        # puts "Debug: table_name_match is: #{table_name_match}" 
        # puts "Debug: table_name is: #{table_name}" if table_name_match 

        values_match = input.match(/values\s*\(([^)]+)\);/i) 
        # puts "Debug: values_match is: #{values_match}" 

        if values_match 
            values_str = values_match[1] 
            values = values_str.split(',').map { |v| v.strip.gsub(/^['"]|['"]$/, '') } 
            # puts "Debug: Extracted values: #{values}" 
            
            # extract column names from teh csv file 
            csv_columns = CSV.read(table_name, headers: true).headers.map(&:downcase) 

            # Create a hash from the extracted values 
            data_hash = Hash[csv_columns.zip(values)] 
            
            # Instantiate and run the insert statement 
            request = MySqliteRequest.new.insert(table_name).values(data_hash) 
            result = request.run 
            puts "Record inserted successfully" 
        else 
            # puts "Debug: No match found for values pattern in the input: #{input}" 
        end 
    end 

    def process_update(input)
        
        # Extract table name
        table_name_match = input.match(/update\s+['"]?(\w+\.\w+)['"]?\s+set/i)
        table_name = table_name_match[1] if table_name_match

        # puts "Debug: input data is: #{input}" 
        # puts "Debug: table_name_match is: #{table_name_match}"
        # puts "Debug: table_name is: #{table_name}" if table_name_match

        # Extract set values 
        set_values_match = input.match(/set\s+(.+?)\s+where/i)
        # puts "Debug: set_values_match is: #{set_values_match}" 
        set_values = Hash[set_values_match[1].scan(/(\w+)\s*=\s*'(.+?)'/)] if set_values_match
        # puts "Debug: set_values is: #{set_values}"

        # extract where conditions
        where_match = input.match(/where\s+(.+?)(?:;|\z)/i)
        # puts "Debug: where_match is: #{where_match}"
        where_conditions = Hash[where_match[1].scan(/(\w+)\s*=\s*'(.+?)'/)] if where_match
        # puts "Debug: where_conditions is: #{where_conditions}"

        # Instantiate and run the update statement
        request = MySqliteRequest.new.update(table_name).set(set_values).where(where_conditions)
        result = request.run 
        display_result(result) 
    end 
    
    def process_delete(input)
        
        #Extract table name
        table_name_match = input.match(/from\s+['"]?(\w+\.\w+)['"]?\s+where/i)
        table_name = table_name_match[1] if table_name_match

        # puts "Debug: input data is: #{input}"
        # puts "Debug: table_name_match is: #{table_name_match}"
        # puts "Debug: table_name is: #{table_name}" if table_name_match

        # Extract where conditions
        where_match = input.match(/where\s+(.+?)(?:;|\z)/i)
        where_conditions = Hash[where_match[1].scan(/(\w+)\s*=\s*'(.+?)'/)] if where_match

        # instantiate and run the delete statement
        request = MySqliteRequest.new.from(table_name).delete.where(where_conditions)
        result = request.run
        display_result(result) 
    end 

    def process_join(input)       
        
        # Extract main table name
        main_table_name_match = input.match(/from\s+['"]?(\w+\.\w+)['"]?\s+join/i)
        main_table_name = main_table_name_match[1] if main_table_name_match

        # Extract join table name
        join_table_name_match = input.match(/join\s+['"]?(\w+\.\w+)['"]?\s+on/i)
        join_table_name = join_table_name_match[1] if join_table_name_match 

        # puts "Debug: Join Table Name from process_join in cli: #{join_table_name}"

        # Extract join conditions
        join_conditions_match = input.match(/join\s+[^;]+on\s+(.+?)(?:;|\z)/i)
        join_conditions_str =join_conditions_match[1] if join_conditions_match
        # puts "Debug: Join Conditions string from process_join in cli: #{join_conditions_str.inspect}" 

        # extract column names from the join condition string 
        column_match = join_conditions_str.match(/(\w+)\.(\w+)\s*=\s*(\w+)\.(\w+)/)
        join_conditions = {
            column_on_db_a: column_match[2],
            filename_db_b: "#{column_match[3]}.csv",
            column_on_db_b: column_match[4]
        } if column_match

        # puts "Debug: Join Conditions from process_join in cli: #{join_conditions.inspect}"

        # check if a select statement follows the join
        select_match = input.match(/select\s+(.+?)(?:\z|from)/i)
        select_columns = select_match[1].split(',').map(&:strip) if select_match

        # puts "Debug: Select Columns from process_join in CLI: #{select_columns.inspect}"
        # puts "Debug: join_condition secondary file name extracted #{join_conditions[:filename_db_b]}" 
        # puts "Debug: join_conditon column extracted from secondary file: #{join_conditions[:column_on_db_b]}"
        
        # run the join statement 
        request = MySqliteRequest.new.from(main_table_name).join(join_conditions[:column_on_db_a], join_conditions[:filename_db_b], join_conditions[:column_on_db_b])

        # Add select request if columns are specified 
        request = request.select(select_columns) if select_columns
        
        result = request.run 
        display_result(result) 
    end 
    

    def display_result(result) 
        if result.nil? || result.empty? 
            puts "No records found." 
        else 
            headers = result.first&.respond_to?(:keys) ? result.first.keys : result.first.headers 
            
            if headers 
                puts headers.join("\t") # or ', ' 

                result.each do |row| 
                    if row.is_a?(CSV::Row) 
                        puts  row.fields.join("\t") # or ', '
                    else 
                        puts row.values.join("\t") # or ', ' 
                    end 
                end 
            else 
                puts "No columns found in the result" 
            end 
        end 
    end 

           
 



      
end 

# Instantiate MySqliteCli and start the command-line interface
database_file = ARGV[0]
MySqliteCli.new(database_file).start 