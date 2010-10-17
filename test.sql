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

