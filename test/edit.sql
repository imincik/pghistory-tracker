-- t_data
INSERT INTO public.test_variables (prop, val) VALUES ('t_data__edit', current_timestamp);

SELECT * FROM gisdata.t_data ORDER BY id;

INSERT INTO gisdata.t_data (fff) VALUES (current_timestamp::text);

DELETE FROM gisdata.t_data WHERE id = (SELECT MIN(id) FROM gisdata.t_data);
SELECT * FROM hist_tracker.gisdata__t_data;

UPDATE gisdata.t_data SET fff = current_timestamp::text WHERE id = (SELECT MIN(id) FROM gisdata.t_data);
SELECT * FROM hist_tracker.gisdata__t_data;

SELECT * FROM gisdata.t_data ORDER BY id;

SELECT * FROM gisdata.t_data_AtTime((SELECT MAX(val)::timestamp FROM public.test_variables WHERE prop = 't_data__edit')) ORDER by id;

SELECT HT_Tag('gisdata', 't_data', 't_data test edit.');


-- v_layer
INSERT INTO public.test_variables (prop, val) VALUES ('v_layer__edit', current_timestamp);

SELECT * FROM gis.v_layer ORDER BY gid;

INSERT INTO gis.v_layer (bbb) VALUES (current_timestamp::text);

DELETE FROM gis.v_layer WHERE gid = (SELECT MIN(gid) FROM gis.v_layer);
SELECT * FROM hist_tracker.gis__v_layer;

UPDATE gis.v_layer SET bbb = current_timestamp::text WHERE gid = (SELECT MIN(gid) FROM gis.v_layer);
SELECT * FROM hist_tracker.gis__v_layer;

SELECT * FROM gis.v_layer ORDER BY gid;

SELECT * FROM gis.v_layer_AtTime((SELECT MAX(val)::timestamp FROM public.test_variables WHERE prop = 'v_layer__edit')) ORDER BY gid;

SELECT HT_Tag('gis', 'v_layer', 'v_layer test edit.');
