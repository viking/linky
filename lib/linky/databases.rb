gem 'dbi'
require 'dbi'
require 'drb'
require 'erb'

require File.dirname(__FILE__) + "/databases/worker"
require File.dirname(__FILE__) + "/databases/resource"
require File.dirname(__FILE__) + "/databases/remote"
require File.dirname(__FILE__) + "/databases/local"

module Linky
  module Databases
    module Helpers
      def database_session(which = :remote, &block)
        resource = case which
          when :remote
            if !session[:db]
              redirect '/'
              return false
            end
            Databases::Remote.new(session[:db])
          when :local
            Databases::Local.new
        end
        result = resource.session(&block)

        case result
        when DBI::DatabaseError
          @db_error = result
          haml :error
        else
          result
        end
      end

      def setup_query(remote)
        # construct query
        columns, conditions, order_by, from, primary_keys = [], [], [], [], []
        params['set'].each_pair do |name, set|
          # look for primary key
          keys = remote.select_all("SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = '#{set['database']}' AND TABLE_NAME = '#{set['from']}' AND COLUMN_KEY = 'PRI' ORDER BY COLUMN_NAME").flatten
          need_subquery = keys.empty?

          # columns
          if need_subquery
            primary_keys << "#{name}._id"
          else
            if keys.length == 1
              primary_keys << "#{name}.#{keys[0]}"
            else
              primary_keys << "CONCAT(#{keys.collect{|k|"#{name}.#{k}"}.join(", ")})"
            end
          end
          columns << "#{primary_keys[-1]} AS #{name}_id"

          set['columns'].split(/\s*,\s*/).each do |column|
            columns << "#{name}.#{column} AS #{name}_#{column}"
          end

          # where
          where = set['where'].empty? ? nil : set['where']

          # order
          order = set['order'].empty? ? nil : set['order']

          # from
          database = set['database']
          table = set['from']
          if need_subquery
            where = " WHERE #{where}"     if where
            order = " ORDER BY #{order}"  if order
            from << %{(SELECT (@#{name}:=(IFNULL(@#{name},0)+1)) AS _id, #{set['columns'].join(", ")} FROM #{database}.#{table}#{where}#{order})}
          else
            from << "#{database}.#{table}"
            conditions << where   if where
            order_by << order     if order
          end
        end
        query = %!SELECT #{columns.join(", ")}\nFROM #{from[0]} A\nLEFT JOIN #{from[1]} B ON #{params['join']}!
        if !conditions.empty?
          query << "\nWHERE (#{conditions.join(") AND (")})"
        end
        if !order_by.empty?
          query << "\nORDER BY #{order_by.join(", ")}"
        end
        query << "\nLIMIT ?, #{options.limit}"

        # save query
        database_session(:local) do |local|
          # cleanup stuff if there are 10 or more sessions
          if local.select_one("SELECT COUNT(*) FROM sessions")[0].to_i >= 10
            local.do("DELETE FROM sessions")
            local.do("DELETE FROM records")
          end

          local.do("INSERT INTO sessions (query, total) VALUES(?, ?)", query, 0)
          session[:session_id] = s_id = local.select_one("SELECT last_insert_rowid() FROM sessions")[0]
          local.do("DELETE FROM records WHERE session_id = ?", s_id)
        end
        query
      end

      def fetch_candidates(dbh)
        count = 0
        if params[:which] =~ /^\d+$/
          s_id = session[:session_id]
          which = params[:which].to_i
          last_id = dbh.select_one("SELECT last_id FROM sessions WHERE id = ?", s_id).first
          return false  if which == last_id

          count = dbh.select_one("SELECT COUNT(*) FROM records WHERE id = ? AND session_id = ? AND target_id IS NULL", which, s_id)[0].to_i
          if count > 0
            target = []
            dbh.select_all("SELECT * FROM records WHERE id = ? AND session_id = ? AND target_id IS NULL", which, s_id) do |row|
              target << [row['name'], row['value']]
            end
            tmp = dbh.select_one("SELECT id FROM records WHERE target_id IS NULL AND id > ? AND session_id = ?", which, s_id)
            next_id = tmp ? tmp.first : nil

            candidates = []
            last_id = nil
            dbh.select_all("SELECT * FROM records WHERE target_id = ? AND session_id = ? ORDER BY id", which, s_id) do |row|
              assoc = candidates.assoc(row['name'])
              candidates << (assoc = [row['name']])    if !assoc
              assoc << row['value']
            end
            return [target, candidates, next_id]
          end
        end
        false
      end

      def start_query
        worker = DRbObject.new(nil, Worker::DRB_URI)
        worker.remote_query({
          :db => session[:db],
          :session_id => session[:session_id],
          :limit => options.limit
        })
      end
    end

    def self.registered(app)
      app.helpers Databases::Helpers
      app.set :limit, 1000
    end
  end
end
