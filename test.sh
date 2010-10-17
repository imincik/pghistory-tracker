#!/bin/bash

dropdb simple_versioning
createdb simple_versioning
createlang plpgsql simple_versioning
createlang plpythonu simple_versioning
psql simple_versioning -f /usr/share/postgresql-8.3-postgis/lwpostgis.sql
psql simple_versioning -f /usr/share/postgresql-8.3-postgis/spatial_ref_sys.sql

psql simple_versioning -c "CREATE SCHEMA sv_history;"
find . -type f -iname "*.sql" -exec psql simple_versioning -f "{}" \;

psql simple_versioning -c "SELECT SV_CreateHistory('gis', 'v_layer');"
psql simple_versioning -c "SELECT SV_CreateHistory('gisdata', 't_data');"

psql simple_versioning -c "INSERT INTO gis.v_layer(aaa, the_geom) VALUES (111, (SELECT ST_GeomFromText('MULTILINESTRING((10 10,20 20))')));"
psql simple_versioning -c "INSERT INTO gis.v_layer(bbb, the_geom) VALUES ('bbb', (SELECT ST_GeomFromText('MULTILINESTRING((15 15,25 25))')));"
psql simple_versioning -c "INSERT INTO gis.v_layer(ccc, the_geom) VALUES (true, (SELECT ST_GeomFromText('MULTILINESTRING((20 20,30 30))')));"
psql simple_versioning -c "SELECT * FROM gis.v_layer;"
psql simple_versioning -c "SELECT * FROM sv_history.gis__v_layer;"

psql simple_versioning -c "INSERT INTO gisdata.t_data(eee, fff, ggg) VALUES (100, 'xxx', true);"
psql simple_versioning -c "INSERT INTO gisdata.t_data(eee, fff, ggg) VALUES (200, 'yyy', true);"
psql simple_versioning -c "INSERT INTO gisdata.t_data(eee, fff, ggg) VALUES (300, 'zzz', false);"
psql simple_versioning -c "SELECT * FROM gisdata.t_data;"
psql simple_versioning -c "SELECT * FROM sv_history.gisdata__t_data;"
echo "**************************************************************************************"
echo "**************************************************************************************"
echo "**************************************************************************************"


#test
echo "************ GIS"
psql simple_versioning -c "DELETE FROM gis.v_layer WHERE bbb = 'bbb';"
psql simple_versioning -c "SELECT * FROM gis.v_layer;"
psql simple_versioning -c "SELECT * FROM sv_history.gis__v_layer;"

psql simple_versioning -c "UPDATE gis.v_layer SET aaa = '100000' WHERE aaa = 111;"
psql simple_versioning -c "SELECT * FROM gis.v_layer;"
psql simple_versioning -c "SELECT * FROM sv_history.gis__v_layer;"

psql simple_versioning -c   "SELECT * FROM gis.v_layer_AtTime('2999-1-1');"


echo "************ GISDATA"
psql simple_versioning -c "DELETE FROM gisdata.t_data WHERE fff = 'xxx';"
psql simple_versioning -c "SELECT * FROM gisdata.t_data;"
psql simple_versioning -c "SELECT * FROM sv_history.gisdata__t_data;"

psql simple_versioning -c "UPDATE gisdata.t_data SET eee = '100000' WHERE eee = 200;"
psql simple_versioning -c "SELECT * FROM gisdata.t_data;"
psql simple_versioning -c "SELECT * FROM sv_history.gisdata__t_data;"

psql simple_versioning -c   "SELECT * FROM gisdata.t_data_AtTime('2999-1-1');"
