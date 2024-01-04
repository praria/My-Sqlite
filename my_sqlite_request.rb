require 'csv'

class MySqliteRequest 
    def initialize()
        # constructor initializes the instance variables to store the state of SQL query being built
        @type_of_request = :none
        @select_columns  = []
        @where_params    = []
        @insert_attributes = {}
        @table_name      = nil
        @join_conditions = {}
        @order_by = nil 
        @update_attributes = {}
        @delete_flag = false
    end

    def from(table_name)
        @table_name = table_name
        self
    end

    def select(columns) 
        @select_columns ||= [] 
        
        if columns == ['*']
            @select_columns = nil 
        else 
            if columns.is_a?(Array) 
                @select_columns += columns.map(&:to_s) 
            elsif columns.is_a?(String) 
                @select_columns << columns.to_s 
            else 
                raise ArgumentError, "Invalid argument type for 'columns'" 
            end             
        end 
        self.setTypeOfRequest(:select)
        self 
    end 
   
    def where(*conditions) 
        if conditions.length == 1 && conditions[0].is_a?(Hash) 
            conditions[0].each do |col, val| 
                @where_params << [col.to_s, val] 
                
            end 
        elsif conditions.length == 2 
            @where_params << [conditions[0].to_s, conditions[1]] 
            
        else 
            raise ArgumentError, "Invalid number of arguments for where method" 
        end 
        self 
    end 

    def join(column_on_db_a, filename_db_b, column_on_db_b)
        @join_conditions = {
            column_on_db_a: column_on_db_a,
            filename_db_b: filename_db_b,
            column_on_db_b: column_on_db_b
        }
        @type_of_request = :join 
        self
    end 

    def order(order_type, column_name) 
        # puts "Debug: Calling order method with order_type: #{order_type}, column_name: #{column_name}" 

        valid_order_types = [:asc, :desc] 
        unless valid_order_types.include?(order_type.to_sym) 
            raise "Invalid order type. Use :asc or :desc." 
        end 
        @order_by = {
            order: order_type.to_sym,
            column_name: column_name.to_s
        }
        self
    end 
    
    def insert(table_name) 
        @type_of_request = :insert
        @table_name = table_name 
        @insert_attributes = {} # Reset the insert attributes
        self
    end 

    # The value method specifies the values to be inserted in the Insert query. It takes a hash of data and sets the @insert_attributes.

    def values(data)
        if (@type_of_request == :insert) 
            #convert keys to symbols 
            @insert_attributes = data.transform_keys(&:to_sym) 
        else 
            raise 'Wrong type of request to call values()'
        end 
        self
    end

    def update(table_name)
        @type_of_request = :update
        @table_name = table_name
        self
    end 

    def set(data)
        @update_attributes = data
        self
    end 


    def delete 
        @type_of_request = :delete
        @delete_flag = true
        self
    end 

    def run 
        if (@type_of_request == :select) 
            _run_select 
        elsif (@type_of_request == :insert)
            _run_insert 
        elsif (@type_of_request == :update)
            _run_update 
        elsif (@type_of_request == :delete)
            _run_delete 
        elsif (@type_of_request == :join) 
            _run_join 
        else 
            raise "Invalid type of request: #{@type_of_request}"
        end 
    end 

    private 

    def setTypeOfRequest(new_type)
        if (@type_of_request == nil? || @type_of_request == new_type)
            @type_of_request = new_type
        else
            # setting current type to new request type
            @type_of_request = new_type
        end
    end 



    def _run_select
        result = [] 
        begin 
            CSV.foreach(@table_name, headers: true) do |row| 
                matching_row = process_row(row) 
                result <<matching_row unless matching_row.empty?
            end 
        rescue CSV::MalformedCSVError => e 
            puts "Error parsing CSV file: #{e.message}" 
        end 
        
        if @order_by 
            # puts "Debug: Result before sorting: #{result.inspect}" 
            result.flatten! # flatten the nested arrays  
            result.sort_by! { |row| row[@order_by[:column_name]].to_s } 
            # puts "Debug: Result after sorting: #{result.inspect}" 
            result.reverse! if @order_by[:order] == :desc 
        end 
        result 
    end 

    def process_row(row) 
        matching_rows = [] 

        # puts "Debug: Entering process_row" 
        # puts "Debug: Processing row: #{row}"

        # check if the row matches the conditions 
        unless row_matching?(row)
            # puts "Debug: Row skipped due to row_matching? check"
            return matching_rows 
        end 

        # puts "Debug: Processing row: #{row}"
        
        if @join_conditions.any?
            join_data = CSV.read(@join_conditions[:filename_db_b], headers: true)
            # puts "Debug: Join Data: #{join_data.inspect}" 

            matching_rows = join_data.find do |join_row| 
                join_value_db_b = join_row[@join_conditions[:column_on_db_b]].to_s.strip
                join_value_db_a = row[@join_conditions[:column_on_db_a]].to_s.strip 
                condition = join_value_db_b == join_value_db_a
                # puts "Debug: Join Condition: #{condition}, Join Value DB B: #{join_value_db_b}, Join Value DB A: #{join_value_db_a}, Join Row: #{join_row.inspect}"
                condition 
            end 

            # puts "Debug: Matching Row from join_data: #{matching_rows.inspect}"

            # Merge matching row into the row if found  
            row = matching_rows ? row.to_h.merge(matching_rows.to_h) : row.to_h                       
        end 

        # puts "Debug: Current row content: #{row}" 
        # puts "Debug: Current row content: #{row.inspect}" 
        # puts "Debug: @select_columns=#{@select_columns.inspect}"

        if @select_columns == ['*'] 
            # when selecting all columns, convert the row to a hash
            selected_row = Hash[row.headers.zip(row.fields)] 
        else 
            # creates a new hash by selecting only the specified columns from the row
            selected_row = Hash[@select_columns.map { |col| [col.to_s, row[col.to_s]&.to_s] }]
            
        end 

        row = selected_row if selected_row.all? { |_, v| !v.nil? } 
        # puts "Debug: Selected row content: #{row}" 
        row
    end 

    def _run_insert 
        CSV.open(@table_name, 'a') do |csv| 
            id_to_insert = @insert_attributes['id'] 
            values_to_insert = @insert_attributes.values_at(*@insert_attributes.keys).compact 

            # Insert id manually if it's provided 
            if id_to_insert 
                csv << [id_to_insert] + values_to_insert 
            else 
                csv << values_to_insert 
            end 
        end
    end

    def _run_update 
        data = CSV.read(@table_name, headers: true)

        if @where_params.any?
            data.each do |row|
                next unless @where_params.all? {|col, val| row[col] == val}

                @update_attributes.each do |col, val|
                    row[col] = val
                end 
            end
            # Open the file for writing (not overwriting)
            CSV.open(@table_name, 'w', write_headers: true) do |csv| 
                # write headers to the file
                csv << data.headers 
                # write all columns of each row to the file
                data.each { |row| csv << row.to_hash.values }
            end 
        end 
    end 

    def _run_delete 
        if @type_of_request == :delete 
            return unless File.exist?(@table_name) 

            data = CSV.read(@table_name, headers: true) 

            if @where_params.any? 
                data_to_keep = data.reject do |row| 
                    @where_params.all? { |col, val| row[col.to_s] == val.to_s} 
                end 

                write_to_file(data_to_keep, data.headers) if data_to_keep.any? 
            else 
                # if no WHERE clause is provided, delete all rows 
                write_to_file([], data.headers) 
            end 
        else 
            puts "Error: You cannot use DELETE method without FROM method" 
        end 
    end 
    

end 

def _run_join 
    return unless File.exist?(@table_name)
    return unless @join_conditions 

    # load data from the main table 
    data_a = CSV.read(@table_name, headers: true)

    # load data from the second table 
    data_b = CSV.read(@join_conditions[:filename_db_b], headers: true) 

    # perform the join based on the specified columns 
    joined_data = data_a.map do |row_a| 
        matching_rows_b = data_b.select { |row_b| row_b[@join_conditions[:column_on_db_b]] == row_a[@join_conditions[:column_on_db_a]] }
        matching_rows_b.each { |row_b| row_a.to_hash.merge!(row_b.to_hash) } 
        CSV::Row.new(row_a.headers, row_a.fields)
    end 
    # write the joined data back to the main table 
    write_to_file(joined_data, data_a.headers) 
end 

private 
def write_to_file(joined_data, headers)
    # open the main table file in append mode and write the joined data
    File.open(@table_name, 'w') do |file|
        # write the headers if the file is empty
        file.puts(headers.join(',')) if file.size.zero?

        # write each joined row to the file
        joined_data.each do |joined_row|
            file.puts(joined_row.fields.join(','))
        end
    end 
end 

def row_matching?(row) 
    return false if row.nil? 
    # If no where conditions are specified, all rows match 
    return true if @where_params.empty? 

    # check if all specified conditions match 
    matching = @where_params.all? do |col, val| 
        match = row[col.to_s]&.to_s == val.to_s 
        # puts "Debug: Condition #{col} = #{val}, Match: #{match}" 
        match
    end 
    # puts "Debug: Row Matching: #{matching}" 
    matching 

end 
    

def _main() 

    # Note1: Please test the request methods with queries in text file - request_queries_for_request_testing.txt
    # Note2: Please test the CLI with queries in text file - sql_queries_for_cli_testing.txt


   # # test case 1: Select operation using wild card '*'

    # request = MySqliteRequest.new
    # request = request.from('nba_player_data_light.csv') 
    # request = request.select('*')
    # result  = request.run 
    # p result 

# ************************************************************

# # test case 2: Select operation using wild card '*'

    # request = MySqliteRequest.new
    # request = request.from('nba_player_data_light.csv') 
    # request = request.select('*') 
    # request = request.where('id', 3)
    # result  = request.run 
    # p result 

# ************************************************************
   
# # test case 3: Select operation using specific column names

    # request = MySqliteRequest.new
    # request = request.from('nba_player_data_light.csv')
    # request = request.select(['name', 'college'])
    # result  = request.run 
    # p result 

# ********************************************************
# # test case 4: DESCENDING Order Operation

        # request = MySqliteRequest.new
        # request = request.from('nba_player_data_light.csv')
        # request = request.select('name') 
        # request = request.order(:desc, 'name')
        # result  = request.run 
        # p result 

# ********************************************************************
# # test case 5: ASCENDING Order Operation

        # request = MySqliteRequest.new
        # request = request.from('nba_player_data_light.csv')
        # request = request.select('name') 
        # request = request.order(:asc, 'name')
        # result  = request.run 
        # p result 

# ********************************************************************

# # test case 6: Select with WHERE Condition - 1

    # request = MySqliteRequest.new
    # request = request.from('nba_player_data_light.csv')
    # request = request.select('id')
    # request = request.where('name', 'Zaid Abdul-Aziz')
    # request = request.where('year_start', '1969') 
    # result  = request.run 
    # p result 

#  *******************************************************************
# test case 7: Select with WHERE Condition - 2

    # request = MySqliteRequest.new
    # request = request.from('nba_player_data_light.csv')
    # request = request.select(['name', 'college'])
    # request = request.where('name', 'Alaa Abdelnaby')
    # request = request.where('birth_day', 'June 24') 
    # result  = request.run 
    # p result 

    
# **********************************************************************************

# test case 8: INSERT Operation

    # request = MySqliteRequest.new
    # request = request.insert('nba_player_data_light.csv')
    # request = request.values({"id" => "10", "name" => "Don Adams", "year_start" => "1971", "year_end" => "1977", "position" => "F", "height" => "6-6", "weight" => "210", "birth_day" => "November 27", "college" => "Northwestern University"})
    # request.run 


# *************************************************************************

# test case 9: UPDATE Operation

    # request = MySqliteRequest.new 
    # request = request.update('nba_player_data_light.csv')
    # request = request.set('college'=> 'Pokhara University')
    # request = request.where('id', '10')
    # result  = request.run
    # p result 

    
# *******************************************************************

# #test case 10: DELETE Operation

    # request = MySqliteRequest.new 
    # request = request.from('nba_player_data_light.csv')
    # request = request.delete
    # request = request.where('id', 10)
    # result  = request.run
    # p result 

    

# *************************************************************

# #test case 11: JOIN Operation
    # request = MySqliteRequest.new
    # request = request.from('orders.csv')
    # request = request.join('customerid', 'orders.csv', 'customerid')
    # result  = request.run 
    # result = result.map(&:to_h)
    # p result
    
end 
_main()
    