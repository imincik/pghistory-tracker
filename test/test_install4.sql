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


BEGIN;
	\i init_schema.sql
	\i install_tracker.sql
	
	CREATE SCHEMA myschema;
	\i test/create_tables.sql

	SELECT plan(4);

	SELECT has_function(
		'public',
		'ht_drop',
		ARRAY['text', 'text'],
		'Check if ht_drop function exists'
	);
	SELECT has_function(
		'public',
		'ht_log',
		ARRAY['text', 'text'],
		'Check if ht_log function exists'
	);
	SELECT has_function(
		'public',
		'ht_log',
		'Check if ht_log function exists'
	);
	SELECT has_function(
		'public',
		'ht_tag',
		ARRAY['text', 'text', 'text'],
		'Check if ht_tag function exists'
	);

	SELECT * FROM finish();
ROLLBACK;
