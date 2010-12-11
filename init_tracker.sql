-- CREATE SCHEMA
CREATE SCHEMA hist_tracker;




-- CREATE TABLES
CREATE TABLE hist_tracker.tags (
	id serial PRIMARY KEY,
	id_tag integer,
	dbschema character varying,
	dbtable character varying,
	dbuser character varying,
	time_tag timestamp,
	changes_count integer,
	message character varying
);




-- # vim: set syntax=python ts=4 sts=4 sw=4 noet: 
