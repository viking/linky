begin
  require 'jeweler'
  Jeweler::Tasks.new do |gemspec|
    gemspec.name = "linky"
    gemspec.summary = "Sinatra app for comparing records"
    gemspec.email = "jeremy.f.stephens@vanderbilt.edu"
    gemspec.homepage = "http://github.com/viking/linky"
    gemspec.description = "Simple Sinatra application for visually comparing records from a database"
    gemspec.authors = ["Jeremy Stephens"]
    gemspec.add_dependency('sinatra',     '>= 0.9.2')
    gemspec.add_dependency('haml',        '>= 2.0.9')
    gemspec.add_dependency('dbi',         '>= 0.4.1')
    gemspec.add_dependency('dbd-mysql',   '>= 0.4.2')
    gemspec.add_dependency('dbd-sqlite3', '>= 1.2.4')
    gemspec.add_dependency('json',        '>= 1.1.6')
    gemspec.add_dependency('daemons',     '>= 1.0.10')
  end
rescue LoadError
  puts "Jeweler not available. Install it with: sudo gem install technicalpickles-jeweler -s http://gems.github.com"
end

desc 'Clean up'
task :clean do
  require 'fileutils'
  FileUtils.rm File.expand_path(File.dirname(__FILE__) + '/db/cache.sqlite3'), :verbose => true
end
