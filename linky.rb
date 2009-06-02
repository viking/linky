require 'rubygems'
require 'sinatra'
require 'haml'
require 'sass'
require 'mysql'
require 'json'
require 'ruby-debug'

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

  def fetch_all(sql)
    rows = []
    result = @dbh.query(sql)
    result.each { |row| rows << row }
    result.free
    rows
  end

  def run_query
    try(:error) do
      @stmt.prepare(session[:query])
      @stmt.execute(@which)

      # process result
      @candidates = []
      a_cols = session[:a_columns]
      b_cols = session[:b_columns]
      ranges = [0..a_cols.count, (a_cols.count+1)..-1]
      @stmt.each do |row|
        a_vals, b_vals = ranges.collect { |r| row[r] }
        unless @target
          @target = {'_id' => a_vals.shift.to_i}
          a_cols.each_with_index do |column, i|
            @target[column] = a_vals[i]
          end
        end

        b_id = b_vals.shift
        if !b_id.nil?
          @candidates << (b = {})
          b_cols.each_with_index do |column, i|
            b[column] = b_vals[i]
          end
        end
      end
    end
  end
end

get '/style.css' do
  sass :style
end

get '/' do
  haml :login
end

post '/' do
  session[:db] = {
    :server   => params[:db][:server],
    :user     => params[:db][:user],
    :password => params[:db][:password]
  }
  try(:login) do
    redirect '/main'
  end
end

get '/main' do
  try do
    @databases = fetch_all("SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA ORDER BY SCHEMA_NAME").flatten
    haml :main
  end
end

get '/tables/:database' do
  try do
    fetch_all("SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = '#{params[:database]}' ORDER BY TABLE_NAME").flatten.to_json
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
  # construct query
  sets = params['set']
  columns = []; from = []
  sets.each_pair do |name, set|
    # columns
    columns << "#{name}._id AS #{name}_id"
    set['columns'] = set['columns'].split(/\s*,\s*/)
    set['columns'].each_with_index do |column, i|
      columns << "#{name}.#{column} AS #{name}#{i}"
    end

    # where
    where = set['where'].empty? ? "" : " WHERE #{set['where']}"

    # order
    set['order'] = set['order'].split(/\s*,\s*/)
    order = set['order'].empty? ? "" : " ORDER BY " + set['order'].join(", ")

    # from
    database = set['database']
    table = set['from']
    from << %{SELECT (@#{name}:=(IFNULL(@#{name},0)+1)) AS _id, #{set['columns'].join(", ")} FROM #{database}.#{table}#{where}#{order}}
  end
  query = <<-EOF
    SELECT #{columns.join(", ")}
    FROM (#{from[0]}) A
    LEFT JOIN (#{from[1]}) B ON #{params['join']}
    WHERE A._id = ?
  EOF

  # setup session
  session[:query] = query
  session[:a_columns] = sets['A']['columns']
  session[:b_columns] = sets['B']['columns']

  # display!
  @which = 1
  run_query
  haml :records, :layout => false
end

get '/candidates/:which' do
  @which = params[:which].to_i
  run_query
  haml :records, :layout => false
end

get '/logout' do
  session.clear
  redirect '/'
end
