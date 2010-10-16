#!/bin/bash
# Author Ivan Mincik, Gista s.r.o., ivan.mincik@gista.sk

dropdb ghistory
createdb ghistory
createlang plpgsql ghistory
createlang plpythonu ghistory
psql ghistory -f /usr/share/postgresql-8.3-postgis/lwpostgis.sql
psql ghistory -f /usr/share/postgresql-8.3-postgis/spatial_ref_sys.sql

CREATE_SCHEMAS="
	CREATE SCHEMA gis;
	CREATE SCHEMA gis_history;
"
psql ghistory -c "$CREATE_SCHEMAS"

find . -type f -iname "*.sql" -exec psql ghistory -f "{}" \;

psql ghistory -c "SELECT gis.G_CreateGISHistory('gis', 'v_layer');"

psql ghistory -c "INSERT INTO gis.v_layer(aaa, the_geom) VALUES (111, (SELECT ST_GeomFromText('MULTILINESTRING((10 10,20 20))')));"
psql ghistory -c "INSERT INTO gis.v_layer(bbb, the_geom) VALUES ('bbb', (SELECT ST_GeomFromText('MULTILINESTRING((15 15,25 25))')));"
psql ghistory -c "INSERT INTO gis.v_layer(ccc, the_geom) VALUES (true, (SELECT ST_GeomFromText('MULTILINESTRING((20 20,30 30))')));"
psql ghistory -c "SELECT * FROM gis.v_layer;"
psql ghistory -c "SELECT * FROM gis_history.hist_gis_v_layer;"
echo "**************************************************************************************"


#test
psql ghistory -c "DELETE FROM gis.v_layer WHERE bbb = 'bbb';"
psql ghistory -c "SELECT * FROM gis.v_layer;"
psql ghistory -c "SELECT * FROM gis_history.hist_gis_v_layer;"

psql ghistory -c "UPDATE gis.v_layer SET aaa = '100000' WHERE aaa = 111;"
psql ghistory -c "SELECT * FROM gis.v_layer;"
psql ghistory -c "SELECT * FROM gis_history.hist_gis_v_layer;"

psql ghistory -c   "SELECT * FROM v_layer_AtTime('2999-1-1');"
