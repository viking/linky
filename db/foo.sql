DROP DATABASE IF EXISTS foo;
CREATE DATABASE foo;
USE foo;
CREATE TABLE people (
  id INT NOT NULL AUTO_INCREMENT,
  name VARCHAR(25),
  favorite_color VARCHAR(25),
  PRIMARY KEY(id)
);
INSERT INTO people VALUES (1, 'Dude',   'blue');
INSERT INTO people VALUES (2, 'Guy',    'red');
INSERT INTO people VALUES (3, 'Bob',    'green');
INSERT INTO people VALUES (4, 'Greg',   'yellow');
INSERT INTO people VALUES (5, 'Harry',  'purple');
INSERT INTO people VALUES (6, 'Ginny',  'pink');
INSERT INTO people VALUES (7, 'Illyra', 'magenta');
