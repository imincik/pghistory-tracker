# uncomment this to load installed pgtap version
#PG_SHAREDIR := $(shell pg_config --sharedir)

test:	test-init-db test-schema test-functions test-edit

clean:	test-clean-db


test-init-db:
	createdb history_tracker_test
	createlang plpgsql history_tracker_test
	createlang plpythonu history_tracker_test
	
	# uncomment this to load installed pgtap version
	#psql history_tracker_test -f $(PG_SHAREDIR)/contrib/pgtap.sql >/dev/null
	psql history_tracker_test -f test/pgtap.sql >/dev/null

	# uncomment this when testing against PostgreSQL 8.3
	#psql history_tracker_test -f compat/array_agg.sql

test-schema:
	psql history_tracker_test -f test/test_schema.sql

test-functions:
	psql history_tracker_test -f test/test_functions.sql

test-edit:
	psql history_tracker_test -f test/test_edit.sql

test-clean-db:
	dropdb history_tracker_test
