module Linky
  module Databases
    class Remote < Resource
      set_adapter 'Mysql'

      def initialize(options = {})
        options[:server] = "localhost"  if options[:server].nil? || options[:server].empty?
        super(options)
      end
    end
  end
end
