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

	SELECT plan(12);

	-- _ht_gettablefields
	SELECT has_function(
		'public',
		'_ht_gettablefields',
		ARRAY['text', 'text'],
		'*** _ht_gettablefields ***'
	);
	SELECT is(_ht_gettablefields('myschema', 'mytable'), 'id,aaa,bbb', '  => Testing return from existing table');
	SELECT is(_ht_gettablefields('myschema', 'none'), NULL, 'Testing return from non existing table');

	-- _ht_gettablepkey
	SELECT has_function(
		'public',
		'_ht_gettablepkey',
		ARRAY['text', 'text'],
		'*** _ht_gettablepkey ***'
	);
	SELECT is(_ht_gettablepkey('myschema', 'mytable'), 'id', '  => Testing return from existing table');
	SELECT is(_ht_gettablepkey('myschema', 'none'), NULL, '  => Testing return from non existing table');

	-- _ht_nexttagvalue
	SELECT has_function(
		'public',
		'_ht_nexttagvalue',
		ARRAY['text', 'text'],
		'*** _ht_nexttagvalue ***'
	);
	SELECT is(_ht_nexttagvalue('myschema', 'mytable'), 1, '   => Check next tag value when no records.');
	INSERT INTO history_tracker.tags (id_tag, dbschema, dbtable, dbuser, time_tag, changes_count, message)
		VALUES (1, 'myschema', 'mytable', 'myuser', now(), 1, 'My message.');
	SELECT is(_ht_nexttagvalue('myschema', 'mytable'), 2, '   => Check next tag value when one record exists.');

	-- _ht_tableexists
	SELECT has_function(
		'public',
		'_ht_tableexists',
		ARRAY['text', 'text'],
		'*** _ht_tableexists function ***'
	);
	SELECT is(_ht_tableexists('myschema', 'mytable'), True, '  => Table should exist');
	SELECT is(_ht_tableexists('myschema', 'none'), False, '  => Table should NOT exist');


	SELECT * FROM finish();
ROLLBACK;
