# uncomment this to load installed pgtap version
#PG_SHAREDIR := $(shell pg_config --sharedir)

test:	test-create-db test-init-schema test-install test-edit test-uninstall test-drop-schema


test-create-db:
	createdb history_tracker_test
	createlang plpgsql history_tracker_test
	createlang plpythonu history_tracker_test
	
	# uncomment this to load installed pgtap version
	#psql history_tracker_test -f $(PG_SHAREDIR)/contrib/pgtap.sql >/dev/null
	psql history_tracker_test -f test/pgtap.sql >/dev/null

	# uncomment this when testing against PostgreSQL 8.3
	#psql history_tracker_test -f compat/array_agg.sql

test-drop-db:
	dropdb history_tracker_test


test-init-schema:
	psql history_tracker_test -f test/test_init_schema.sql

test-install:
	psql history_tracker_test -f test/test_install.sql

test-edit:
	psql history_tracker_test -f test/test_edit.sql

test-uninstall:
	make test-drop-db
	make test-create-db
	psql history_tracker_test -f test/test_uninstall.sql

test-drop-schema:
	psql history_tracker_test -f test/test_drop_schema.sql
	dropdb history_tracker_test
