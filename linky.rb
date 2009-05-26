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
        yield
      rescue Mysql::Error => @db_error
        @dbh = nil
        haml view_for_failure
      ensure
        @dbh.close   if @dbh
      end
    else
      redirect '/'
    end
  end

  def fetch_all_rows(sql)
    rows = []
    result = @dbh.query(sql)
    result.each { |row| rows << row }
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

post '/query' do
  try(:error) do
    sets = params['set']
    columns = %w{A B}.inject([]) do |arr, set|
      sets[set]['columns'].split(/\s*,\s*/).each_with_index do |name, i|
        arr << "#{set}.#{name} AS #{set}#{i}"
      end
      arr
    end.join(', ')
    order = %w{A B}.inject([]) do |arr, set|
      sets[set]['order'].split(/\s*,\s*/).each_with_index do |str, i|
        arr << "#{set}.#{str}"
      end
      arr
    end.join(', ')
    @dbh.query(<<-EOF)
      SELECT #{columns}
      FROM #{sets['A']['database']}.#{sets['A']['from']} A
      JOIN #{sets['B']['database']}.#{sets['B']['from']} B ON #{params['join']}
      ORDER BY #{order}
    EOF
  end
end

get '/logout' do
  session.clear
  redirect '/'
end
