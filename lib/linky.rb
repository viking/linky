require 'haml'
require 'sass'
require 'json'
require 'ruby-debug'
require 'sinatra/base'

# middleware!
require File.join(File.dirname(__FILE__), 'linky', 'databases')
require File.join(File.dirname(__FILE__), 'linky', 'history')

module Linky
  class Application < Sinatra::Base
    register Linky::Databases
    register Linky::History

    configure do
      set :static, true
      set :public, File.join(File.dirname(__FILE__), '..', 'public')
      set :views,  File.join(File.dirname(__FILE__), '..', 'views')

      use Rack::Session::Cookie, :secret => "li'l linky"
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
      database_session do |dbh|
        redirect '/main'
      end
    end

    get '/main' do
      database_session do |dbh|
        @databases = dbh.select_all(<<-EOF).flatten
          SELECT SCHEMA_NAME
          FROM INFORMATION_SCHEMA.SCHEMATA
          WHERE SCHEMA_NAME != 'information_schema'
          ORDER BY SCHEMA_NAME
        EOF
        get_last
        haml :main
      end
    end

    get '/tables/:database' do
      database_session do |dbh|
        dbh.select_all("SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = '#{params[:database]}' ORDER BY TABLE_NAME").flatten.to_json
      end
    end

    get '/columns/:database/:table' do
      database_session do |dbh|
        dbh.select_all("SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = '#{params[:database]}' AND TABLE_NAME = '#{params[:table]}' ORDER BY COLUMN_NAME").flatten.to_json
      end
    end

    post '/query' do
      database_session do |dbh|
        set_last
        @query = setup_query(dbh)

        haml :query, :layout => false
      end
    end

    get '/status' do
      database_session(:local) do |dbh|
        row = dbh.select_one("SELECT status, exception, first_id, done FROM sessions WHERE id = ?", session[:session_id])
        if row[0] == 'error'
          @db_error = Marshal.load(row[1])
          row[1] = haml(:error, :layout => false)
        end
        row.to_h.to_json
      end
    end

    get '/candidates/:which' do
      database_session(:local) do |ldbh|
        @results = fetch_results(ldbh)
        if @results
          haml :records, :layout => false
        else
          ldbh.do("UPDATE sessions SET status = 'working' WHERE id = ?", session[:session_id])
          start_query
          "working"
        end
      end
    end

    get '/target_ids/:q' do
      database_session(:local) do |ldbh|
        ldbh.select_all("SELECT record_id FROM records WHERE record_id LIKE ? AND session_id = ?", params[:q], session[:session_id]).join("\n")
      end
    end

    get '/logout' do
      session.clear
      redirect '/'
    end
  end
end
