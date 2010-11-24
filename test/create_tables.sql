SET client_min_messages = warning;

-- Helper table for test variables
CREATE TABLE public.test_variables
(
	id serial PRIMARY KEY,
	prop character varying,
	val character varying
);


-- Standard database table 't_data'
CREATE SCHEMA gisdata;
CREATE TABLE gisdata.t_data
(
	id serial PRIMARY KEY,
	eee integer,
	fff character varying,
	ggg boolean
);
CREATE INDEX idx_t_data_id
	ON gisdata.t_data
	USING btree
	(id);

INSERT INTO gisdata.t_data(eee, fff, ggg) VALUES (100, 'xxx', true);
INSERT INTO gisdata.t_data(eee, fff, ggg) VALUES (200, 'yyy', true);
INSERT INTO gisdata.t_data(eee, fff, ggg) VALUES (300, 'zzz', false);
SELECT * FROM gisdata.t_data;




-- PostGIS table 'v_layer'
CREATE SCHEMA gis;
CREATE TABLE gis.v_layer
(
	gid serial PRIMARY KEY,
	aaa integer,
	bbb character varying,
	ccc boolean
);
SELECT AddGeometryColumn('gis','v_layer','the_geom','-1','MULTILINESTRING',2);

CREATE INDEX idx_v_layer_gid
	ON gis.v_layer
	USING btree
	(gid);

CREATE INDEX spx_v_layer
	ON gis.v_layer
	USING gist
	(the_geom);

INSERT INTO gis.v_layer(aaa, the_geom) VALUES (111, (SELECT ST_GeomFromText('MULTILINESTRING((10 10,20 20))')));
INSERT INTO gis.v_layer(bbb, the_geom) VALUES ('bbb', (SELECT ST_GeomFromText('MULTILINESTRING((15 15,25 25))')));
INSERT INTO gis.v_layer(ccc, the_geom) VALUES (true, (SELECT ST_GeomFromText('MULTILINESTRING((20 20,30 30))')));
SELECT * FROM gis.v_layer;
