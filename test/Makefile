
test:	test-init-db test-schema test-functions test-edit

clean:	test-clean-db


test-init-db: 
	createdb history_tracker_test
	createlang plpgsql history_tracker_test
	createlang plpythonu history_tracker_test
	
	psql history_tracker_test -f /usr/share/postgresql/8.4/contrib/pgtap.sql >/dev/null

test-schema:
	psql history_tracker_test -f pgtap_schema.sql

test-functions:
	psql history_tracker_test -f pgtap_functions.sql

test-edit:
	psql history_tracker_test -f pgtap_edit.sql

test-clean-db:
	dropdb history_tracker_test
