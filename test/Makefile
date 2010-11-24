
test:	test-init-db test-init-history

clean:	test-clean-db


test-init-db: 
	createdb history_tracker_test
	createlang plpgsql history_tracker_test
	createlang plpythonu history_tracker_test
	psql history_tracker_test -f /usr/share/postgresql-8.3-postgis/lwpostgis.sql
	psql history_tracker_test -f /usr/share/postgresql-8.3-postgis/spatial_ref_sys.sql
	psql history_tracker_test -f create_tables.sql
	psql history_tracker_test -f ../history_tracker.sql
	
test-init-history:
	psql history_tracker_test -c "SELECT HT_CreateHistory('gisdata', 't_data');"
	psql history_tracker_test -c "SELECT HT_CreateHistory('gis', 'v_layer');"
	psql history_tracker_test -c "SELECT * FROM hist_tracker.gisdata__t_data;"
	psql history_tracker_test -c "SELECT * FROM hist_tracker.gis__v_layer;"

test-edit:
	psql history_tracker_test -f edit.sql


test-clean-db:
	dropdb history_tracker_test

test-clean-history:
	psql history_tracker_test -c "SELECT HT_RemoveHistory('gisdata', 't_data');"
	psql history_tracker_test -c "SELECT HT_RemoveHistory('gis', 'v_layer');"
	psql history_tracker_test -c "\dt hist_tracker.*"
	psql history_tracker_test -c "SELECT * FROM hist_tracker.tags"
