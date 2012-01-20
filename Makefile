# uncomment this to load installed pgtap version
#PG_SHAREDIR := $(shell pg_config --sharedir)

test:	test-create-db test-init-schema test-install test-edit test-uninstall test-drop-schema


test-create-db:
	@createdb history_tracker_test
	@createlang plpgsql history_tracker_test
	@createlang plpythonu history_tracker_test
	
	@# uncomment this to load installed pgtap version
	@#psql history_tracker_test -f $(PG_SHAREDIR)/contrib/pgtap.sql >/dev/null
	@psql history_tracker_test -f test/pgtap.sql >/dev/null

	@# uncomment this when testing against PostgreSQL 8.3
	@#psql history_tracker_test -f compat/array_agg.sql

	@echo

test-drop-db:
	@dropdb history_tracker_test

	@echo

test-init-schema:
	@pg_prove --dbname history_tracker_test test/test_init_schema.sql

	@echo

test-install:
	@pg_prove --dbname history_tracker_test test/test_install*.sql

	@echo

test-edit:
	@pg_prove --dbname history_tracker_test test/test_edit.sql

	@echo

test-uninstall:
	@make test-drop-db
	@make test-create-db
	@pg_prove --dbname history_tracker_test test/test_uninstall.sql

	@echo

test-drop-schema:
	@pg_prove --dbname history_tracker_test test/test_drop_schema.sql
	@dropdb history_tracker_test

	@echo
