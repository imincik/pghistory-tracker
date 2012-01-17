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


--BEGIN; can not use transaction because we need real timestamp values (all timestamps in trasaction equals !)
	\i init_schema.sql
	\i install_tracker.sql
	
	CREATE SCHEMA myschema;
	\i test/create_tables.sql

	CREATE TABLE checkpoints
	(
		name character varying PRIMARY KEY,
		creation timestamp DEFAULT now()
	);



	SELECT plan(47);
	
	-- TEST EMPTY TABLE
	SELECT is(ht_init('myschema', 'mytable'), 'History is enabled.', '*** Init history (empty table). ***');
	SELECT is(MAX(id), NULL, '   => Check if data table is empty.') FROM myschema.mytable;
	SELECT is(MAX(id), NULL, '   => Check if history table is empty.') FROM history_tracker.myschema__mytable;
	
	CREATE TABLE checkpoint_empty_init AS SELECT * FROM myschema.mytable;
	INSERT INTO checkpoints VALUES ('checkpoint_empty_init');
	

	-- INSERT #1
	INSERT INTO myschema.mytable (aaa, bbb) VALUES (1, 'a');
	SELECT is(COUNT(*)::integer, 1, '   => INSERT data #1.') FROM myschema.mytable;
	SELECT results_eq(
		'SELECT id, aaa, bbb::text, time_start IS NULL, time_end IS NULL, id_history
			FROM history_tracker.myschema__mytable ORDER BY id_history',
		'VALUES (1, 1, ''a'', False, True, 1)',
		'   => Check timestamp values in history table.'
		);
	CREATE TABLE checkpoint_empty_insert1 AS SELECT * FROM myschema.mytable;
	INSERT INTO checkpoints VALUES ('checkpoint_empty_insert1');
	-- tag
	SELECT is(ht_tag('myschema', 'mytable', 'checkpoint_empty_insert1'), 'Tag recorded.', '   => Tag checkpoint_empty_insert1.');
	SELECT results_eq(
		'SELECT id, id_tag, dbschema::text, dbtable::text, changes_count, message::text FROM history_tracker.tags ORDER BY id',
		'VALUES (1, 1, ''myschema'', ''mytable'', 0, ''History init.''),
			(2, 2, ''myschema'', ''mytable'', 1, ''checkpoint_empty_insert1'')',
		'   => Test tags after INSERT #1.'
	);
	-- diff
	SELECT results_eq(
		'SELECT operation::text, id, aaa, bbb::text FROM myschema.mytable_diff(
			(SELECT creation FROM checkpoints WHERE name = ''checkpoint_empty_init'')) ORDER BY id',
		'VALUES (''+'', 1, 1, ''a'')',
		'   => Test diff after INSERT #1.'
	);

	-- INSERT #2
	INSERT INTO myschema.mytable (aaa, bbb) VALUES (2, 'b');
	INSERT INTO myschema.mytable (aaa, bbb) VALUES (3, 'c');
	INSERT INTO myschema.mytable (aaa, bbb) VALUES (4, 'd');
	SELECT is(COUNT(*)::integer, 4, '   => INSERT data #2.') FROM myschema.mytable;
	SELECT results_eq(
		'SELECT id, aaa, bbb::text, time_start IS NULL, time_end IS NULL, id_history
			FROM history_tracker.myschema__mytable ORDER BY id_history',
		'VALUES (1, 1, ''a'', False, True, 1), (2, 2, ''b'', False, True, 2),
			(3, 3, ''c'', False, True, 3), (4, 4, ''d'', False, True, 4)',
		'   => Check timestamp values in history table.'
		);
	CREATE TABLE checkpoint_empty_insert2 AS SELECT * FROM myschema.mytable;
	INSERT INTO checkpoints VALUES ('checkpoint_empty_insert2');
	-- tag
	SELECT is(ht_tag('myschema', 'mytable', 'checkpoint_empty_insert2'), 'Tag recorded.', '   => Tag checkpoint_empty_insert2.');
	SELECT results_eq(
		'SELECT id, id_tag, dbschema::text, dbtable::text, changes_count, message::text FROM history_tracker.tags ORDER BY id',
		'VALUES (1, 1, ''myschema'', ''mytable'', 0, ''History init.''),
			(2, 2, ''myschema'', ''mytable'', 1, ''checkpoint_empty_insert1''),
			(3, 3, ''myschema'', ''mytable'', 3, ''checkpoint_empty_insert2'')',
		'   => Test tags after INSERT #2.'
	);
	-- diff
	SELECT results_eq(
		'SELECT operation::text, id, aaa, bbb::text FROM myschema.mytable_diff(
			(SELECT creation FROM checkpoints WHERE name = ''checkpoint_empty_init'')) ORDER BY id',
		'VALUES (''+'', 1, 1, ''a''), (''+'', 2, 2, ''b''),
		(''+'', 3, 3, ''c''), (''+'', 4, 4, ''d'')',
		'   => Test diff after INSERT #2.'
	);


	-- UPDATE #1
	UPDATE myschema.mytable SET aaa = 11 WHERE aaa = 1;
	SELECT is(COUNT(*)::integer, 4, '   => UPDATE data #1.') FROM myschema.mytable;
	SELECT results_eq(
		'SELECT id, aaa, bbb::text, time_start IS NULL, time_end IS NULL, time_end > time_start, id_history
			FROM history_tracker.myschema__mytable ORDER BY id_history',
		'VALUES (1, 11, ''a'', False, True, NULL, 1), (2, 2, ''b'', False, True, NULL, 2),
			(3, 3, ''c'', False, True, NULL, 3), (4, 4, ''d'', False, True, NULL, 4),

			(1, 1, ''a'', False, False, True, 5)',
		'   => Check timestamp values in history table.'
		);
	CREATE TABLE checkpoint_empty_update1 AS SELECT * FROM myschema.mytable;
	INSERT INTO checkpoints VALUES ('checkpoint_empty_update1');
	-- tag
	SELECT is(ht_tag('myschema', 'mytable', 'checkpoint_empty_update1'), 'Tag recorded.', '   => Tag checkpoint_empty_update1.');
	SELECT results_eq(
		'SELECT id, id_tag, dbschema::text, dbtable::text, changes_count, message::text FROM history_tracker.tags ORDER BY id',
		'VALUES (1, 1, ''myschema'', ''mytable'', 0, ''History init.''),
			(2, 2, ''myschema'', ''mytable'', 1, ''checkpoint_empty_insert1''),
			(3, 3, ''myschema'', ''mytable'', 3, ''checkpoint_empty_insert2''),
			(4, 4, ''myschema'', ''mytable'', 1, ''checkpoint_empty_update1'')',
		'   => Test tags after UPDATE #1.'
	);
	-- diff
	SELECT results_eq(
		'SELECT operation::text, id, aaa, bbb::text FROM myschema.mytable_diff(
			(SELECT creation FROM checkpoints WHERE name = ''checkpoint_empty_init'')) ORDER BY id',
		'VALUES (''+'', 1, 11, ''a''), (''+'', 2, 2, ''b''),
		(''+'', 3, 3, ''c''), (''+'', 4, 4, ''d'')',
		'   => Test diff after UPDATE #1.'
	);

	-- UPDATE #2
	UPDATE myschema.mytable SET aaa = 22 WHERE aaa = 2;
	UPDATE myschema.mytable SET aaa = 33 WHERE aaa = 3;
	UPDATE myschema.mytable SET aaa = 44 WHERE aaa = 4;
	SELECT is(COUNT(*)::integer, 4, '   => UPDATE data #2.') FROM myschema.mytable;
	SELECT results_eq(
		'SELECT id, aaa, bbb::text, time_start IS NULL, time_end IS NULL, time_end > time_start, id_history
			FROM history_tracker.myschema__mytable ORDER BY id_history',
		'VALUES (1, 11, ''a'', False, True, NULL, 1), (2, 22, ''b'', False, True, NULL, 2),
			(3, 33, ''c'', False, True, NULL, 3), (4, 44, ''d'', False, True, NULL, 4),
			
			(1, 1, ''a'', False, False, True, 5), (2, 2, ''b'', False, False, True, 6),
			(3, 3, ''c'', False, False, True, 7), (4, 4, ''d'', False, False, True, 8)',
		'   => Check timestamp values in history table.'
		);
	CREATE TABLE checkpoint_empty_update2 AS SELECT * FROM myschema.mytable;
	INSERT INTO checkpoints VALUES ('checkpoint_empty_update2');
	-- tag
	SELECT is(ht_tag('myschema', 'mytable', 'checkpoint_empty_update2'), 'Tag recorded.', '   => Tag checkpoint_empty_update2.');
	SELECT results_eq(
		'SELECT id, id_tag, dbschema::text, dbtable::text, changes_count, message::text FROM history_tracker.tags ORDER BY id',
		'VALUES (1, 1, ''myschema'', ''mytable'', 0, ''History init.''),
			(2, 2, ''myschema'', ''mytable'', 1, ''checkpoint_empty_insert1''),
			(3, 3, ''myschema'', ''mytable'', 3, ''checkpoint_empty_insert2''),
			(4, 4, ''myschema'', ''mytable'', 1, ''checkpoint_empty_update1''),
			(5, 5, ''myschema'', ''mytable'', 3, ''checkpoint_empty_update2'')',
		'   => Test tags after UPDATE #2.'
	);
	-- diff
	SELECT results_eq(
		'SELECT operation::text, id, aaa, bbb::text FROM myschema.mytable_diff(
			(SELECT creation FROM checkpoints WHERE name = ''checkpoint_empty_init'')) ORDER BY id',
		'VALUES (''+'', 1, 11, ''a''), (''+'', 2, 22, ''b''),
		(''+'', 3, 33, ''c''), (''+'', 4, 44, ''d'')',
		'   => Test diff after UPDATE #2.'
	);


	-- DELETE #1
	DELETE FROM myschema.mytable WHERE aaa = 11;
	SELECT is(COUNT(*)::integer, 3, '   => DELETE data #1.') FROM myschema.mytable;
	SELECT results_eq(
		'SELECT id, aaa, bbb::text, time_start IS NULL, time_end IS NULL, time_end > time_start, id_history
			FROM history_tracker.myschema__mytable ORDER BY id_history',
		'VALUES (1, 11, ''a'', False, False, True, 1), (2, 22, ''b'', False, True, NULL, 2),
			(3, 33, ''c'', False, True, NULL, 3), (4, 44, ''d'', False, True, NULL, 4),
			
			(1, 1, ''a'', False, False, True, 5), (2, 2, ''b'', False, False, True, 6),
			(3, 3, ''c'', False, False, True, 7), (4, 4, ''d'', False, False, True, 8)',
		'   => Check timestamp values in history table.'
		);
	CREATE TABLE checkpoint_empty_delete1 AS SELECT * FROM myschema.mytable;
	INSERT INTO checkpoints VALUES ('checkpoint_empty_delete1');
	-- tag
	SELECT is(ht_tag('myschema', 'mytable', 'checkpoint_empty_delete1'), 'Tag recorded.', '   => Tag checkpoint_empty_delete1.');
	SELECT results_eq(
		'SELECT id, id_tag, dbschema::text, dbtable::text, changes_count, message::text FROM history_tracker.tags ORDER BY id',
		'VALUES (1, 1, ''myschema'', ''mytable'', 0, ''History init.''),
			(2, 2, ''myschema'', ''mytable'', 1, ''checkpoint_empty_insert1''),
			(3, 3, ''myschema'', ''mytable'', 3, ''checkpoint_empty_insert2''),
			(4, 4, ''myschema'', ''mytable'', 1, ''checkpoint_empty_update1''),
			(5, 5, ''myschema'', ''mytable'', 3, ''checkpoint_empty_update2''),
			(6, 6, ''myschema'', ''mytable'', 1, ''checkpoint_empty_delete1'')',
		'   => Test tags after DELETE #1.'
	);
	-- diff
	SELECT results_eq(
		'SELECT operation::text, id, aaa, bbb::text FROM myschema.mytable_diff(
			(SELECT creation FROM checkpoints WHERE name = ''checkpoint_empty_init'')) ORDER BY id',
		'VALUES (''+'', 2, 22, ''b''),
		(''+'', 3, 33, ''c''), (''+'', 4, 44, ''d'')',
		'   => Test diff after DELETE #1.'
	);

	-- DELETE #2
	DELETE FROM myschema.mytable WHERE aaa = 22;
	DELETE FROM myschema.mytable WHERE aaa = 33;
	DELETE FROM myschema.mytable WHERE aaa = 44;
	SELECT is(COUNT(*)::integer, 0, '   => DELETE data #2.') FROM myschema.mytable;
	SELECT results_eq(
		'SELECT id, aaa, bbb::text, time_start IS NULL, time_end IS NULL, time_end > time_start, id_history
			FROM history_tracker.myschema__mytable ORDER BY id_history',
		'VALUES (1, 11, ''a'', False, False, True, 1), (2, 22, ''b'', False, False, True, 2),
			(3, 33, ''c'', False, False, True, 3), (4, 44, ''d'', False, False, True, 4),
			
			(1, 1, ''a'', False, False, True, 5), (2, 2, ''b'', False, False, True, 6),
			(3, 3, ''c'', False, False, True, 7), (4, 4, ''d'', False, False, True, 8)',
		'   => Check timestamp values in history table.'
		);
	CREATE TABLE checkpoint_empty_delete2 AS SELECT * FROM myschema.mytable;
	INSERT INTO checkpoints VALUES ('checkpoint_empty_delete2');
	-- tag
	SELECT is(ht_tag('myschema', 'mytable', 'checkpoint_empty_delete2'), 'Tag recorded.', '   => Tag checkpoint_empty_delete2.');
	SELECT results_eq(
		'SELECT id, id_tag, dbschema::text, dbtable::text, changes_count, message::text FROM history_tracker.tags ORDER BY id',
		'VALUES (1, 1, ''myschema'', ''mytable'', 0, ''History init.''),
			(2, 2, ''myschema'', ''mytable'', 1, ''checkpoint_empty_insert1''),
			(3, 3, ''myschema'', ''mytable'', 3, ''checkpoint_empty_insert2''),
			(4, 4, ''myschema'', ''mytable'', 1, ''checkpoint_empty_update1''),
			(5, 5, ''myschema'', ''mytable'', 3, ''checkpoint_empty_update2''),
			(6, 6, ''myschema'', ''mytable'', 1, ''checkpoint_empty_delete1''),
			(7, 7, ''myschema'', ''mytable'', 3, ''checkpoint_empty_delete2'')',
		'   => Test tags after DELETE #2.'
	);
	-- diff
	SELECT results_eq(
		'SELECT COUNT(*)::integer FROM myschema.mytable_diff(
			(SELECT creation FROM checkpoints WHERE name = ''checkpoint_empty_init''))',
		'VALUES (0)',
		'   => Test diff after DELETE #2.'
	);

	-- invalid tags
	SELECT is(ht_tag('myschema', 'mytable', 'no changes'),
		'No tag written.',
		'   => Invalid tag with no pending changes.');
	SELECT throws_ok('SELECT ht_tag(''noschema'', ''notable'', ''no changes'')',
		'P0001',
		'History is not enabled or table does not exists.',
		'   => Invalid tag on non existing table.');


	-- TEST CHECKPOINTS
	-- AtTime function
	SELECT results_eq(
		'SELECT * FROM myschema.mytable_attime((SELECT creation FROM checkpoints WHERE name = ''checkpoint_empty_init''))',
		'SELECT * FROM checkpoint_empty_init',
		'   => Test checkpoint_empty_init.'
	);
	SELECT results_eq(
		'SELECT * FROM myschema.mytable_attime((SELECT creation FROM checkpoints WHERE name = ''checkpoint_empty_insert1''))',
		'SELECT * FROM checkpoint_empty_insert1',
		'   => Test checkpoint_empty_insert1.'
	);
	SELECT results_eq(
		'SELECT * FROM myschema.mytable_attime((SELECT creation FROM checkpoints WHERE name = ''checkpoint_empty_insert2''))',
		'SELECT * FROM checkpoint_empty_insert2',
		'   => Test checkpoint_empty_insert2.'
	);
	SELECT results_eq(
		'SELECT * FROM myschema.mytable_attime((SELECT creation FROM checkpoints WHERE name = ''checkpoint_empty_update1''))',
		'SELECT * FROM checkpoint_empty_update1',
		'   => Test checkpoint_empty_update1.'
	);
	SELECT results_eq(
		'SELECT * FROM myschema.mytable_attime((SELECT creation FROM checkpoints WHERE name = ''checkpoint_empty_update2''))',
		'SELECT * FROM checkpoint_empty_update2',
		'   => Test checkpoint_empty_update2.'
	);
	SELECT results_eq(
		'SELECT * FROM myschema.mytable_attime((SELECT creation FROM checkpoints WHERE name = ''checkpoint_empty_delete1''))',
		'SELECT * FROM checkpoint_empty_delete1',
		'   => Test checkpoint_empty_delete1.'
	);
	SELECT results_eq(
		'SELECT * FROM myschema.mytable_attime((SELECT creation FROM checkpoints WHERE name = ''checkpoint_empty_delete2''))',
		'SELECT * FROM checkpoint_empty_delete2',
		'   => Test checkpoint_empty_delete2.'
	);

	-- clean 
	SELECT is(ht_drop('myschema', 'mytable'), 'History is disabled.', '*** Drop history (empty table). ***');
	DROP TABLE myschema.mytable;



	-- TEST POPULATED TABLE
	\i test/create_tables.sql
	
	INSERT INTO myschema.mytable (aaa, bbb) VALUES (1, 'a');
	INSERT INTO myschema.mytable (aaa, bbb) VALUES (2, 'b');
	INSERT INTO myschema.mytable (aaa, bbb) VALUES (3, 'c');
	INSERT INTO myschema.mytable (aaa, bbb) VALUES (4, 'd');
	
	SELECT is(ht_init('myschema', 'mytable'), 'History is enabled.', '*** Init history (populated table). ***');
	SELECT is(MAX(id), 4, '   => Check if data table has data.') FROM myschema.mytable;
	SELECT results_eq(
		'SELECT id, aaa, bbb::text, time_start IS NULL, time_end IS NULL, id_history
			FROM history_tracker.myschema__mytable ORDER BY id_history',
		'VALUES (1, 1, ''a'', False, True, 1), (2, 2, ''b'', False, True, 2),
			(3, 3, ''c'', False, True, 3), (4, 4, ''d'', False, True, 4)',
		'   => Check timestamp values in history table.'
		);

	SELECT is(ht_init('myschema', 'mytable'), 'History is enabled.', '*** Upgrade history triggers. ***');

	SELECT * FROM finish();
--ROLLBACK;
