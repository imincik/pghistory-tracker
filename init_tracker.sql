-- hist_tracker
CREATE SCHEMA hist_tracker;


-- _HT_NextTagValue
CREATE OR REPLACE FUNCTION _HT_NextTagValue(dbschema text, dbtable text)
	RETURNS integer AS
$BODY$

dbschema = args[0]
dbtable = args[1]

vars = {'dbschema': dbschema, 'dbtable': dbtable} 

val = plpy.execute("((SELECT MAX(id_tag) FROM hist_tracker.tags WHERE dbschema = '%(dbschema)s' AND dbtable = '%(dbtable)s'));" % vars )[0]['max']

if val is None:
	return 1
else:
	return val + 1

$BODY$
LANGUAGE 'plpythonu' VOLATILE;

-- hist_tracker.tags
CREATE TABLE hist_tracker.tags (
	id serial PRIMARY KEY,
	id_tag integer CHECK (id_tag = _HT_NextTagValue(dbschema, dbtable)),
	dbschema character varying,
	dbtable character varying,
	dbuser character varying,
	time_tag timestamp,
	changes_count integer,
	message character varying
);

-- # vim: set syntax=python ts=4 sts=4 sw=4 noet: 
