module Linky
  module Databases
    class Resource
      @@adapters = {}
      def self.set_adapter(name)
        @@adapters[self] = name
      end

      def initialize(options = {})
        raise NotImplementedError   if self.class == Resource
        raise "no adapter set"      unless @@adapters[self.class]
        @options = options

        @dsn = "DBI:#{@@adapters[self.class]}"
        parts = []
        parts << "host=#{@options[:server]}"    if @options[:server]
        parts << "port=#{@options[:port]}"      if @options[:port]
        parts << @options[:database]            if @options[:database]
        @dsn << ":#{parts.join(";")}" unless parts.empty?
      end

      def connection
        if @dbh.nil?
          @dbh = DBI.connect(@dsn, @options[:user], @options[:password])
          @dbh.convert_types = false
        end
        @dbh
      end

      def disconnect
        @dbh.disconnect   if @dbh
        @dbh = nil
      end

      def session
        begin
          yield(self)
        rescue
          $!
        ensure
          disconnect
        end
      end

      def transaction
        connection
        @dbh['AutoCommit'] = false
        begin
          yield(self)
          @dbh.commit
        rescue
          @dbh.rollback
          $!
        ensure
          disconnect
        end
      end

      %w{select_all select_one prepare do}.each do |method|
        class_eval(<<-EOF, __FILE__, __LINE__)
          def #{method}(*args, &block)
            connection.#{method}(*args, &block)
          end
        EOF
      end
    end
  end
end
