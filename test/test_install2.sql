-- Turn off echo and keep things quiet.
\set ECHO
\set QUIET 1

-- Format the output for nice TAP.
\pset format unaligned
\pset tuples_only true
\pset pager

-- Revert all changes on failure.
\set ON_ERROR_ROLLBACK 1
\set ON_ERROR_STOP true
\set QUIET 1

SET client_min_messages = WARNING;

-- _ht_createdifftype
BEGIN;
	\i init_schema.sql
	\i install_tracker.sql
	
	CREATE SCHEMA myschema;
	\i test/create_tables.sql

	SELECT plan(3);
	SELECT has_function(
		'public',
		'_ht_createdifftype',
		ARRAY['text', 'text'],
		'*** _ht_createdifftype ***'
	);
	SELECT is(_ht_createdifftype('myschema', 'mytable'), True, '   => Create diff type.');
	SELECT has_type(
		'myschema',
		'ht_mytable_difftype',
		'   => Check if diff type exists.'
	);

	SELECT * FROM finish();
ROLLBACK;
