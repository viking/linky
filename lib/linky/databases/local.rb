module Linky
  module Databases
    class Local < Resource
      DBFILE = File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "..", "db", "cache.sqlite3"))
      set_adapter 'SQLite3'

      def initialize
        super({:database => DBFILE})
      end

      def connection
        do_init = !File.exist?(DBFILE)
        super
        if do_init
          @dbh.do("CREATE TABLE records (id INTEGER PRIMARY KEY, record_id TEXT, name TEXT, value TEXT, target_id INTEGER, session_id INTEGER)")
          @dbh.do("CREATE TABLE sessions (id INTEGER PRIMARY KEY, query TEXT, status TEXT, total INTEGER, done INTEGER, first_id TEXT, last_id TEXT, label_length INTEGER, value_length INTEGER, exception RAW)")
        end
        @dbh
      end
    end
  end
end
