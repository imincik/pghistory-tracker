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




-- ht_init and ht_drop
BEGIN;
	\i init_schema.sql
	\i install_tracker.sql
	
	CREATE SCHEMA myschema;
	\i test/create_tables.sql

	SELECT plan(23);
	
	-- ht_init
	SELECT has_function(
		'public',
		'ht_init',
		ARRAY['text', 'text'],
		'*** ht_init ***'
	);
	SELECT is(ht_init('myschema', 'mytable'), 'History is enabled.', '   => Init table.');
	SELECT has_table(
		'history_tracker',
		'myschema__mytable',
		'   => Check if history table exists.'
	);
	SELECT has_column(
		'history_tracker',
		'myschema__mytable',
		'time_start',
		'   => Check if history table has column time_start.'
	);
	SELECT has_column(
		'history_tracker',
		'myschema__mytable',
		'time_end',
		'   => Check if history table has column time_end.'
	);
	SELECT has_column(
		'history_tracker',
		'myschema__mytable',
		'dbuser',
		'   => Check if history table has column dbuser.'
	);
	SELECT has_column(
		'history_tracker',
		'myschema__mytable',
		'id_history',
		'   => Check if history table has column id_history.'
	);
	SELECT col_is_pk(
		'history_tracker',
		'myschema__mytable',
		'id_history',
		'   => Check if id_history column is PK.'
	);
	SELECT has_index(
		'history_tracker',
		'myschema__mytable',
		'idx_myschema__mytable_id_history',
		ARRAY['id_history'],
		'   => Check if history table has index on id_history column.'
	);
	SELECT has_index(
		'history_tracker',
		'myschema__mytable',
		'idx_myschema__mytable_id',
		ARRAY['id'],
		'   => Check if history table has index on column which is PK at original table.'
	);
	-- TODO: test updating all time_start values to now()
	SELECT results_eq(
		'SELECT id_tag, dbschema::text, dbtable::text, message::text, changes_count FROM history_tracker.tags',
		'VALUES (1, ''myschema'', ''mytable'', ''History init.'', 0)',
		'   => Check initial tag values.'
	);
	SELECT has_type(
		'myschema',
		'ht_mytable_difftype',
		'   => Check if diff type exists.'
	);
	SELECT functions_are(
		'myschema',
		ARRAY['mytable_attime', 'mytable_diff', 'mytable_difftotag', 'tg_mytable_insert', 'tg_mytable_update', 'tg_mytable_delete'],
		'   => Check if created table functions exists.'
	);
	SELECT has_trigger(
		'myschema',
		'mytable',
		'tg_mytable_insert',
		'   => Check if insert trigger exists.'
	);
	SELECT has_trigger(
		'myschema',
		'mytable',
		'tg_mytable_update',
		'   => Check if update trigger exists.'
	);
	SELECT has_trigger(
		'myschema',
		'mytable',
		'tg_mytable_delete',
		'   => Check if delete trigger exists.'
	);
	SELECT has_rule(
		'history_tracker',
		'myschema__mytable',
		'myschema__mytable_del',
		'   => Check if delete rule exists.'
	);



	-- ht_drop
	SELECT has_function(
		'public',
		'ht_drop',
		ARRAY['text', 'text'],
		'*** ht_drop ***'
	);
	SELECT is(ht_drop('myschema', 'mytable'), 'History is disabled.', '   => Drop table.');
	SELECT functions_are(
		'myschema',
		NULL,
		'   => Check if table functions has gone.'
	);
	SELECT hasnt_type(
		'myschema',
		'ht_mytable_difftype',
		'   => Check if diff type has gone.'
	);
	SELECT results_eq(
		'SELECT COUNT(*)::integer FROM history_tracker.tags',
		$$ VALUES (0) $$,
		'   => Check if tags has gone.'
	);
	SELECT hasnt_table(
		'history_tracker',
		'myschema__mytable',
		'   => Check if history table has gone.'
	);

	SELECT * FROM finish();
ROLLBACK;


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
