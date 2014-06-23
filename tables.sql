DROP TABLE parking_fact;
DROP TABLE block_dimension;
DROP TABLE regulation_dimension;
DROP TABLE regulation_time_dimension;
DROP TYPE borough;
DROP TYPE side;

CREATE TYPE borough AS ENUM ('Bronx', 'Brooklyn', 'Manhattan', 'Queens', 'Staten');
CREATE TYPE side AS ENUM ('N', 'E', 'S', 'W', 'M');

CREATE TABLE parking_fact (
		block_id integer NOT NULL,
		regulation_id integer NOT NULL,
		"Start position" integer NOT NULL,
		"Length" integer NOT NULL,
		"Parking spots" integer NOT NULL,
		"Weighted parking spots" real NOT NULL,
		PRIMARY KEY (block_id, "Start position")
		);
CREATE INDEX parking_fact_block_id_index ON parking_fact (block_id);
CREATE INDEX parking_fact_regulation_id_index ON parking_fact (regulation_id);

CREATE TABLE block_dimension (
		block_id integer NOT NULL PRIMARY KEY,
		"Borough" borough NOT NULL,
		"Street name" text NOT NULL,
		"From street" text NOT NULL,
		"To street" text NOT NULL,
		"Side" side NOT NULL
		);
CREATE INDEX block_dimension_borough_index ON block_dimension ("Borough");
CREATE INDEX block_dimension_street_index ON block_dimension ("Street name");

CREATE TABLE regulation_dimension (
		regulation_id integer NOT NULL PRIMARY KEY,
		"Hours free parking" real NOT NULL,
		"Hours metered parking" real NOT NULL,
		"Hours street cleaning" real NOT NULL,
		"Hours no parking" real NOT NULL,
		"Hours no standing" real NOT NULL,
		"Hours no stopping" real NOT NULL,
		"Hours bus stop" real NOT NULL,
		"Angle parking" boolean NOT NULL,
		"Special interest" text NOT NULL
		);

CREATE TABLE regulation_time_dimension (
		regulation_id integer NOT NULL,
		"Day of week" integer NOT NULL,
		"Half hour" integer NOT NULL,
		"Free parking" integer NOT NULL,
		"Metered parking" integer NOT NULL,
		"Street cleaning" integer NOT NULL,
		"No parking" integer NOT NULL,
		PRIMARY KEY (regulation_id, "Day of week", "Half hour")
		);
CREATE INDEX regulation_time_dimension_regulation_id_index
		ON regulation_time_dimension (regulation_id);
CREATE INDEX regulation_time_dimension_day_index
		ON regulation_time_dimension ("Day of week");
CREATE INDEX regulation_time_dimension_half_hour_index
		ON regulation_time_dimension ("Half hour");


