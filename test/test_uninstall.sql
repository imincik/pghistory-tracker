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

BEGIN;
	\i init_schema.sql
	\i install_tracker.sql
	\i uninstall_tracker.sql

SELECT plan(8);
	
	-- _ht_gettablefields
	SELECT hasnt_function(
		'public',
		'_ht_gettablefields',
		ARRAY['text', 'text'],
		'*** _ht_gettablefields ***'
	);

	-- _ht_gettablepkey
	SELECT hasnt_function(
		'public',
		'_ht_gettablepkey',
		ARRAY['text', 'text'],
		'*** _ht_gettablepkey ***'
	);

	-- _ht_tableexists
	SELECT hasnt_function(
		'public',
		'_ht_tableexists',
		ARRAY['text', 'text'],
		'*** _ht_tableexists function ***'
	);
	
	SELECT hasnt_function(
		'public',
		'_ht_createdifftype',
		ARRAY['text', 'text'],
		'*** _ht_createdifftype ***'
	);
	SELECT hasnt_function(
		'public',
		'_ht_init',
		ARRAY['text', 'text'],
		'*** _ht_init ***'
	);
	SELECT hasnt_function(
		'public',
		'_ht_drop',
		ARRAY['text', 'text'],
		'*** _ht_drop ***'
	);
	SELECT hasnt_function(
		'public',
		'_ht_tag',
		ARRAY['text', 'text', 'text'],
		'*** _ht_tag ***'
	);
	SELECT hasnt_function(
		'public',
		'_ht_log',
		ARRAY['text', 'text'],
		'*** _ht_createdifftype ***'
	);

SELECT * FROM finish();
ROLLBACK;
