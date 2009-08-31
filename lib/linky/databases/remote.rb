module Linky
  module Databases
    class Remote < Resource
      set_adapter 'Mysql'

      def initialize(options = {})
        options[:server] = "localhost"  if options[:server].nil? || options[:server].empty?
        options[:port]   = 3306         if options[:port].nil? || options[:port].empty?
        super(options)
      end
    end
  end
end
