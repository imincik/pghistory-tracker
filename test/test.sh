#!/bin/bash

dropdb history_tracker_test
createdb history_tracker_test
createlang plpgsql history_tracker_test
createlang plpythonu history_tracker_test
psql history_tracker_test -f /usr/share/postgresql-8.3-postgis/lwpostgis.sql
psql history_tracker_test -f /usr/share/postgresql-8.3-postgis/spatial_ref_sys.sql

psql history_tracker_test -f ../history_tracker.sql
psql history_tracker_test -f test.sql

psql history_tracker_test -c "SELECT HT_CreateHistory('gis', 'v_layer');"
psql history_tracker_test -c "SELECT HT_CreateHistory('gisdata', 't_data');"

psql history_tracker_test -c "INSERT INTO gis.v_layer(aaa, the_geom) VALUES (111, (SELECT ST_GeomFromText('MULTILINESTRING((10 10,20 20))')));"
psql history_tracker_test -c "INSERT INTO gis.v_layer(bbb, the_geom) VALUES ('bbb', (SELECT ST_GeomFromText('MULTILINESTRING((15 15,25 25))')));"
psql history_tracker_test -c "INSERT INTO gis.v_layer(ccc, the_geom) VALUES (true, (SELECT ST_GeomFromText('MULTILINESTRING((20 20,30 30))')));"
psql history_tracker_test -c "SELECT * FROM gis.v_layer;"
psql history_tracker_test -c "SELECT * FROM hist_tracker.gis__v_layer;"

psql history_tracker_test -c "INSERT INTO gisdata.t_data(eee, fff, ggg) VALUES (100, 'xxx', true);"
psql history_tracker_test -c "INSERT INTO gisdata.t_data(eee, fff, ggg) VALUES (200, 'yyy', true);"
psql history_tracker_test -c "INSERT INTO gisdata.t_data(eee, fff, ggg) VALUES (300, 'zzz', false);"
psql history_tracker_test -c "SELECT * FROM gisdata.t_data;"
psql history_tracker_test -c "SELECT * FROM hist_tracker.gisdata__t_data;"
echo "**************************************************************************************"
echo "**************************************************************************************"
echo "**************************************************************************************"


#test
echo "************ GIS"
psql history_tracker_test -c "DELETE FROM gis.v_layer WHERE bbb = 'bbb';"
psql history_tracker_test -c "SELECT * FROM gis.v_layer;"
psql history_tracker_test -c "SELECT * FROM hist_tracker.gis__v_layer;"

psql history_tracker_test -c "UPDATE gis.v_layer SET aaa = '100000' WHERE aaa = 111;"
psql history_tracker_test -c "SELECT * FROM gis.v_layer;"
psql history_tracker_test -c "SELECT * FROM hist_tracker.gis__v_layer;"

psql history_tracker_test -c "SELECT * FROM gis.v_layer_AtTime('2999-1-1');"

psql history_tracker_test -c "SELECT HT_RemoveHistory('gis', 'v_layer');"
psql history_tracker_test -c "\dt gis.*"


echo "************ GISDATA"
psql history_tracker_test -c "DELETE FROM gisdata.t_data WHERE fff = 'xxx';"
psql history_tracker_test -c "SELECT * FROM gisdata.t_data;"
psql history_tracker_test -c "SELECT * FROM hist_tracker.gisdata__t_data;"

psql history_tracker_test -c "UPDATE gisdata.t_data SET eee = '100000' WHERE eee = 200;"
psql history_tracker_test -c "SELECT * FROM gisdata.t_data;"
psql history_tracker_test -c "SELECT * FROM hist_tracker.gisdata__t_data;"

psql history_tracker_test -c "SELECT * FROM gisdata.t_data_AtTime('2999-1-1');"

psql history_tracker_test -c "SELECT HT_RemoveHistory('gisdata', 't_data');"
psql history_tracker_test -c "\dt gisdata.*"


psql history_tracker_test -c "\dt hist_tracker.*"


psql history_tracker_test -c "SELECT HT_CreateHistory('gis', 'v_layer');"
psql history_tracker_test -c "SELECT HT_CreateHistory('gisdata', 't_data');"
psql history_tracker_test -c "SELECT * FROM gis.v_layer;"
psql history_tracker_test -c "SELECT * FROM hist_tracker.gis__v_layer;"
psql history_tracker_test -c "SELECT * FROM gis.v_layer;"
psql history_tracker_test -c "SELECT * FROM hist_tracker.gis__v_layer;"
