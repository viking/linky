require 'yaml'

module Linky
  module History
    module Helpers
      def get_last
        @last = File.exist?(options.history) ? YAML.load_file(options.history) : Hash.new(Hash.new(Hash.new))
      end

      def set_last
        File.open(options.history, 'w') { |f| f.puts params.to_yaml }
      end
    end

    def self.registered(app)
      app.helpers History::Helpers
      app.set :history, File.join(File.dirname(__FILE__),'..','..','last.yml')
    end
  end
end
