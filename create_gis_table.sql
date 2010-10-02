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

SELECT GT_Register_Layer('layer')
