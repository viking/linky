require 'rubygems'
require 'mysql'
require 'forgery'
require 'highline/import'

number = ARGV[0].to_i
password = ask("Root password: ") { |q| q.echo = false }
dbh = Mysql.real_connect('localhost', 'root', password)
stmt = dbh.stmt_init

chars = %w{ | / - \\ }
%w{foo bar}.each do |name|
  dbh.query "DROP DATABASE IF EXISTS #{name}"
  dbh.query "CREATE DATABASE #{name}"
  dbh.query "GRANT ALL PRIVILEGES ON #{name}.* to linky@localhost"
  dbh.select_db(name)
  dbh.query <<-EOF
    CREATE TABLE people (
      id INT NOT NULL AUTO_INCREMENT,
      first_name VARCHAR(50),
      last_name VARCHAR(50),
      shirt_size VARCHAR(3),
      PRIMARY KEY(id)
    )
  EOF

  print "#{name}: "
  stmt.prepare("INSERT INTO people (first_name, last_name, shirt_size) VALUES(?, ?, ?)")
  number.times do |i|
    print chars[i % 4]
    stmt.execute(Forgery(:name).first_name, Forgery(:name).last_name, Forgery(:personal).shirt_size)
    print "\b"
    $stdout.flush
  end
  puts "done!"
end
