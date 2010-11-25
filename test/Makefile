
test:	test-init-db test-init-history test-edit test-clean-history test-init-history

clean:	test-clean-db


test-init-db: 
	createdb history_tracker_test
	createlang plpgsql history_tracker_test
	createlang plpythonu history_tracker_test
	find /usr/share/postgresql-* -iname 'lwpostgis.sql' -exec psql -q history_tracker_test -f "{}" \;
	find /usr/share/postgresql-* -iname 'spatial_ref_sys.sql' -exec psql -q history_tracker_test -f "{}" \;
	psql -q history_tracker_test -f create_tables.sql
	psql -q --set VERBOSITY=terse history_tracker_test -f ../history_tracker.sql
	
test-init-history:
	psql -q --set VERBOSITY=terse history_tracker_test -c "SELECT HT_CreateHistory('gisdata', 't_data');"
	psql -q --set VERBOSITY=terse history_tracker_test -c "SELECT HT_CreateHistory('gis', 'v_layer');"
	psql -q history_tracker_test -c "SELECT * FROM hist_tracker.gisdata__t_data;"
	psql -q history_tracker_test -c "SELECT * FROM hist_tracker.gis__v_layer;"
	psql -q history_tracker_test -c "SELECT * FROM HT_Log()"

test-edit:
	psql -q history_tracker_test -f edit.sql


test-clean-db:
	dropdb history_tracker_test

test-clean-history:
	psql -q history_tracker_test -c "SELECT HT_RemoveHistory('gisdata', 't_data');"
	psql -q history_tracker_test -c "SELECT HT_RemoveHistory('gis', 'v_layer');"
	psql -q history_tracker_test -c "\dt hist_tracker.*"
	psql -q history_tracker_test -c "SELECT * FROM HT_Log()"
