require 'rubygems'
require ::File.join(::File.dirname(__FILE__), 'lib', 'linky')

use Linky::Application
run Sinatra::Base
