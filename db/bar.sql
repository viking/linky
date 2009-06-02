DROP DATABASE IF EXISTS bar;
CREATE DATABASE bar;
GRANT ALL PRIVILEGES ON bar.* to linky@localhost;

USE bar;
CREATE TABLE people (name VARCHAR(25), favorite_animal VARCHAR(25));
INSERT INTO people VALUES ('Dude',   'dog');
INSERT INTO people VALUES ('Dude',   'hawk');
INSERT INTO people VALUES ('Amy',    'bear');
INSERT INTO people VALUES ('Bob',    'turtle');
INSERT INTO people VALUES ('Fred',   'dragon');
INSERT INTO people VALUES ('Harry',  'hamster');
INSERT INTO people VALUES ('Ginny',  'marmot');
INSERT INTO people VALUES ('Dixie',  'cat');
