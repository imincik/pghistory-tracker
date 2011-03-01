
test:	test-init-db test-init-history test-init-edit test-edit-insert test-edit-delete test-edit-update test-edit-finish test-patch test-init-history

clean:	test-clean-history test-clean-db


test-init-db: 
	createdb history_tracker_test
	createdb history_tracker_test2
	createlang plpgsql history_tracker_test
	createlang plpythonu history_tracker_test
	find /usr/share/postgresql* -iname 'lwpostgis.sql' -exec psql -q history_tracker_test -f "{}" \;
	find /usr/share/postgresql* -iname 'postgis.sql' -exec psql -q history_tracker_test -f "{}" \;
	find /usr/share/postgresql* -iname 'spatial_ref_sys.sql' -exec psql -q history_tracker_test -f "{}" \;
	psql  history_tracker_test -f ../init_tracker.sql | ./runtest.sh -r init-db-init_tracker.out
	psql  history_tracker_test -f ../history_tracker.sql | ./runtest.sh -r init-db-history_tracker.out
	psql -q history_tracker_test -f create_tables.sql | ./runtest.sh -r init-db-create_tables.out
	
test-init-history:
	psql -q --set VERBOSITY=terse history_tracker_test -c "SELECT HT_Init('gisdata', 't_data');" | ./runtest.sh -r init-history-ht_init_t_data.out
	psql -q --set VERBOSITY=terse history_tracker_test -c "SELECT HT_Init('gis', 'v_layer');" | ./runtest.sh -r init-history-ht_init_v_layer.out
	psql -q --set VERBOSITY=terse history_tracker_test -f create_functions.sql
	
	psql -q history_tracker_test -c "SELECT * FROM gisdata.t_data ORDER BY id;" | ./runtest.sh -r init-history-t_data_atstart.out
	psql -q history_tracker_test -c "SELECT * FROM gis.v_layer ORDER BY gid;" | ./runtest.sh -r init-history-v_layer_atstart.out

	psql -q history_tracker_test -c "SELECT * FROM test_gisdata__t_data();" | ./runtest.sh -r init-history-t_data.out
	psql -q history_tracker_test -c "SELECT * FROM test_gis__v_layer();" | ./runtest.sh -r init-history-v_layer.out
	
	psql -q history_tracker_test -c "SELECT * FROM test_tags();" | ./runtest.sh -r init-history-ht_log.out

	pg_dump history_tracker_test | psql -q --set VERBOSITY=terse history_tracker_test2 -o /dev/null

test-init-edit:
	psql -q --set VERBOSITY=terse history_tracker_test -c "INSERT INTO public.test_variables (prop, val) VALUES ('t_data__edit', current_timestamp);"
	psql -q --set VERBOSITY=terse history_tracker_test -c "INSERT INTO public.test_variables (prop, val) VALUES ('v_layer__edit', current_timestamp);"
	psql -q history_tracker_test -c "SELECT * FROM gisdata.t_data ORDER BY id;" | ./runtest.sh -r init-edit-t_data.out
	psql -q history_tracker_test -c "SELECT * FROM gis.v_layer ORDER BY gid;" | ./runtest.sh -r init-edit-v_layer.out

test-edit-insert:
	psql -q history_tracker_test -c "INSERT INTO gisdata.t_data (eee) VALUES ((SELECT COUNT(*) FROM gisdata.t_data));"
	psql -q history_tracker_test -c "INSERT INTO gis.v_layer (aaa) VALUES ((SELECT COUNT(*) FROM gis.v_layer));"
	
	psql -q history_tracker_test -c "SELECT HT_Tag('gisdata', 't_data', 't_data insert.');" | ./runtest.sh -r edit-insert-ht_tag_t_data.out
	psql -q history_tracker_test -c "SELECT HT_Tag('gis', 'v_layer', 'v_layer insert.');" | ./runtest.sh -r edit-insert-ht_tag_v_layer.out

	psql -q history_tracker_test -c "SELECT * FROM test_gisdata__t_data();" | ./runtest.sh -r edit-insert-t_data.out
	psql -q history_tracker_test -c "SELECT * FROM test_gis__v_layer();" | ./runtest.sh -r edit-insert-v_layer.out

	psql -q history_tracker_test -c "SELECT * FROM test_tags();" | ./runtest.sh -r edit-insert-ht_log.out

test-edit-delete:
	psql -q history_tracker_test -c "DELETE FROM gisdata.t_data WHERE id = (SELECT MIN(id) FROM gisdata.t_data);"
	psql -q history_tracker_test -c "DELETE FROM gis.v_layer WHERE gid = (SELECT MIN(gid) FROM gis.v_layer);"
	
	psql -q history_tracker_test -c "SELECT HT_Tag('gisdata', 't_data', 't_data delete.');" | ./runtest.sh -r edit-delete-ht_tag_t_data.out
	psql -q history_tracker_test -c "SELECT HT_Tag('gis', 'v_layer', 'v_layer delete.');" | ./runtest.sh -r edit-delete-ht_tag_v_layer.out

	psql -q history_tracker_test -c "SELECT * FROM test_gisdata__t_data();" | ./runtest.sh -r edit-delete-t_data.out
	psql -q history_tracker_test -c "SELECT * FROM test_gis__v_layer();" | ./runtest.sh -r edit-delete-v_layer.out

	psql -q history_tracker_test -c "SELECT * FROM test_tags();" | ./runtest.sh -r edit-delete-ht_log.out

test-edit-update:
	psql -q history_tracker_test -c "UPDATE gisdata.t_data SET eee = ((SELECT COUNT(*) FROM gisdata.t_data)) WHERE id = (SELECT MIN(id) FROM gisdata.t_data);"
	psql -q history_tracker_test -c "UPDATE gis.v_layer SET aaa = ((SELECT COUNT(*) FROM gis.v_layer)) WHERE gid = (SELECT MIN(gid) FROM gis.v_layer);"
	
	psql -q history_tracker_test -c "SELECT HT_Tag('gisdata', 't_data', 't_data update.');" | ./runtest.sh -r edit-update-ht_tag_t_data.out
	psql -q history_tracker_test -c "SELECT HT_Tag('gis', 'v_layer', 'v_layer update.');" | ./runtest.sh -r edit-update-ht_tag_v_layer.out

	psql -q history_tracker_test -c "SELECT * FROM test_gisdata__t_data();" | ./runtest.sh -r edit-update-t_data.out
	psql -q history_tracker_test -c "SELECT * FROM test_gis__v_layer();" | ./runtest.sh -r edit-update-v_layer.out

	psql -q history_tracker_test -c "SELECT * FROM test_tags();" | ./runtest.sh -r edit-update-ht_log.out

test-edit-finish:
	psql -q history_tracker_test -c "SELECT * FROM gisdata.t_data ORDER BY id;" | ./runtest.sh -r edit-finish-t_data.out
	psql -q history_tracker_test -c "SELECT * FROM gisdata.t_data_AtTime((SELECT MAX(val)::timestamp FROM \
		public.test_variables WHERE prop = 't_data__edit')) ORDER by id;" | ./runtest.sh -r edit-finish-t_data_attime.out

	psql -q history_tracker_test -c "SELECT * FROM gis.v_layer ORDER BY gid;" | ./runtest.sh -r edit-finish-v_layer.out
	psql -q history_tracker_test -c "SELECT * FROM gis.v_layer_AtTime((SELECT MAX(val)::timestamp FROM \
		public.test_variables WHERE prop = 'v_layer__edit')) ORDER BY gid;" | ./runtest.sh -r edit-finish-v_layer_attime.out

test-patch:
	../bin/export_patch.py "dbname=history_tracker_test" gisdata t_data 1 | psql -q history_tracker_test2
	../bin/export_patch.py "dbname=history_tracker_test" gis v_layer 1 | psql -q history_tracker_test2
	psql -q history_tracker_test2 -c "SELECT * FROM gisdata.t_data;" | ./runtest.sh -r patch-t_data.out
	psql -q history_tracker_test2 -c "SELECT * FROM gis.v_layer;" | ./runtest.sh -r patch-v_layer.out


test-clean-history:
	psql -q history_tracker_test -c "SELECT HT_Drop('gisdata', 't_data');" -o /dev/null
	psql -q history_tracker_test -c "SELECT HT_Drop('gis', 'v_layer');" -o /dev/null

test-clean-db:
	dropdb history_tracker_test
	dropdb history_tracker_test2
