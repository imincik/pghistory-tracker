SET client_min_messages = warning;

-- Helper functions
CREATE TYPE test_gisdata__t_data_type AS (
	id integer,
	eee integer,
	fff character varying,
	ggg boolean,
	time_start_end boolean,
	dbuser character varying,
	id_history integer
);

CREATE OR REPLACE FUNCTION test_gisdata__t_data()
RETURNS SETOF test_gisdata__t_data_type AS 
$$
SELECT id, eee, fff, ggg, (time_start < time_end), dbuser, id_history FROM history_tracker.gisdata__t_data;
$$
LANGUAGE SQL;


CREATE TYPE test_gis__v_layer_type AS (
	gid integer,
	aaa integer,
	bbb character varying,
	ccc boolean,
	time_start_end boolean,
	dbuser character varying,
	id_history integer
);

CREATE OR REPLACE FUNCTION test_gis__v_layer()
RETURNS SETOF test_gis__v_layer_type AS 
$$
SELECT gid, aaa, bbb, ccc, (time_start < time_end), dbuser, id_history FROM history_tracker.gis__v_layer;
$$
LANGUAGE SQL;


CREATE TYPE test_tags_type AS (
	id integer,
	id_tag integer,
	dbschema character varying,
	dbtable character varying,
	dbuser character varying,
	changes_count integer,
	message character varying
);

CREATE OR REPLACE FUNCTION test_tags()
RETURNS SETOF test_tags_type AS 
$$
SELECT id, id_tag, dbschema, dbtable, dbuser, changes_count, message FROM history_tracker.tags;
$$
LANGUAGE SQL;
