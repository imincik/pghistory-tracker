-- t_data
INSERT INTO public.test_variables (prop, val) VALUES ('t_data__edit', current_timestamp);

SELECT * FROM gisdata.t_data;
DELETE FROM gisdata.t_data WHERE fff = 'xxx';
SELECT * FROM hist_tracker.gisdata__t_data;

UPDATE gisdata.t_data SET eee = '100000' WHERE eee = 200;
SELECT * FROM hist_tracker.gisdata__t_data;

SELECT * FROM gisdata.t_data_AtTime((SELECT MAX(val)::timestamp FROM public.test_variables WHERE prop = 't_data__edit')) ORDER by id;



-- v_layer
INSERT INTO public.test_variables (prop, val) VALUES ('v_layer__edit', current_timestamp);

SELECT * FROM gis.v_layer;
DELETE FROM gis.v_layer WHERE bbb = 'bbb';
SELECT * FROM hist_tracker.gis__v_layer;

UPDATE gis.v_layer SET aaa = '100000' WHERE aaa = 111;
SELECT * FROM hist_tracker.gis__v_layer;

SELECT * FROM gis.v_layer_AtTime((SELECT MAX(val)::timestamp FROM public.test_variables WHERE prop = 'v_layer__edit')) ORDER BY gid;

