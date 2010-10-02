#!/bin/bash
# Author Ivan Mincik, Gista s.r.o., ivan.mincik@gista.sk

dropdb ghistory
createdb ghistory
createlang plpgsql ghistory
createlang plpythonu ghistory
psql ghistory -f /usr/share/postgresql-8.3-postgis/lwpostgis.sql
psql ghistory -f /usr/share/postgresql-8.3-postgis/spatial_ref_sys.sql

psql ghistory -f ./install_projekt2.sql


CREATE_SCHEMAS="
	CREATE SCHEMA gis;
	CREATE SCHEMA gis_history;
"
psql ghistory -c "$CREATE_SCHEMAS"


psql ghistory -f ./create_gis_table.sql
