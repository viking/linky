require 'rubygems'
require 'sinatra'
require 'haml'
require 'mysql'
require 'json'

enable :sessions

helpers do
  def try(view_for_failure = nil)
    if session[:db]
      begin
        @dbh = Mysql.real_connect(session[:db][:server], session[:db][:user], session[:db][:password])
        @stmt = @dbh.stmt_init
        yield
      rescue Mysql::Error => @db_error
        @dbh = nil
        haml view_for_failure
      ensure
        @dbh.close    if @dbh
        @stmt.close   if @stmt
      end
    else
      redirect '/'
    end
  end

  def fetch_all_rows(sql)
    rows = []
    result = @dbh.query(sql)
    result.each { |row| rows << row }
    result.free
    rows
  end
end

get '/' do
  haml :start
end

post '/' do
  session[:db] = {
    :server   => params[:db][:server],
    :user     => params[:db][:user],
    :password => params[:db][:password]
  }
  try(:start) do
    redirect '/main'
  end
end

get '/main' do
  try do
    @databases = fetch_all_rows("SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA ORDER BY SCHEMA_NAME").flatten
    haml :main
  end
end

get '/tables/:database' do
  try do
    fetch_all_rows("SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = '#{params[:database]}' ORDER BY TABLE_NAME").flatten.to_json
  end
end

get '/columns/:database/:table' do
  try do
    result = @dbh.query(<<-EOF)
      SELECT COLUMN_NAME, COLUMN_KEY
      FROM INFORMATION_SCHEMA.COLUMNS
      WHERE TABLE_SCHEMA = '#{params[:database]}' AND
            TABLE_NAME = '#{params[:table]}'
      ORDER BY COLUMN_NAME
    EOF
    hash = { :columns => [], :keys => [] }
    result.each do |row|
      hash[:columns] << row[0]
      hash[:keys]    << row[0]    if row[1] == "PRI"
    end
    result.free
    hash.to_json
  end
end

post '/query' do
  try(:error) do
    # construct query
    sets = params['set']
    columns = []; order = []; from = []; where = []
    sets.each_pair do |name, set|
      # columns
      columns << "#{name}._id AS #{name}_id"
      set['columns'] = set['columns'].split(/\s*,\s*/)
      set['columns'].each_with_index do |column, i|
        columns << "#{name}.#{column} AS #{name}#{i}"
      end

      # from
      database = set['database']
      table    = set['from']
      from << %{SELECT (@#{name}:=(IFNULL(@#{name},0)+1)) AS _id, #{table}.* FROM #{database}.#{table}}

      # where
      where << "(#{set['where']})"  unless set['where'].empty?

      # order
      set['order'] = set['order'].split(/\s*,\s*/)
      set['order'].each do |column|
        order << "#{name}.#{column}"
      end
    end
    @query = <<-EOF
      SELECT #{columns.join(", ")}
      FROM (#{from[0]}) A
      LEFT JOIN (#{from[1]}) B ON #{params['join']}
    EOF
    @query << "  WHERE #{where.join(" AND ")}\n"  unless where.empty?
    @query << "  ORDER BY #{order.join(", ")}"    unless order.empty?
    @stmt.prepare(@query)
    @stmt.execute

    # process result
    @records = {}
    a_cols = sets['A']['columns']
    b_cols = sets['B']['columns']
    ranges = [0..a_cols.count, (a_cols.count+1)..-1]
    @stmt.each do |row|
      a_vals, b_vals = row.values_at(*ranges)
      a_id = a_vals.shift
      unless @records[a_id]
        @records[a_id] = { 'A' => (a = {}), 'B' => [] }
        a_cols.each_with_index do |column, i|
          a[column] = a_vals[i]
        end
      end

      b_id = b_vals.shift
      @records[a_id]['B'] << (b = {})
      b_cols.each_with_index do |column, i|
        b[column] = row["B#{i}"]
      end
    end

    # display!
    haml :query
  end
end

get '/logout' do
  session.clear
  redirect '/'
end
