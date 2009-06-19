module Linky
  module Helpers
    def get_last
      @last = File.exist?(options.history) ? YAML.load_file(options.history) : Hash.new(Hash.new(Hash.new))
    end

    def set_last
      File.open(options.history, 'w') { |f| f.puts params.to_yaml }
    end

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
      @stmt.prepare(session[:query])
      @stmt.execute(@which * options.limit)
      results = session[:results]

      # clear out all but the last set
      @candidates = []
      a_cols = session[:a_columns]
      b_cols = session[:b_columns]
      ranges = [0..a_cols.length, (a_cols.length+1)..-1]
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
