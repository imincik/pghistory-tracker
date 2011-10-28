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
	\i ../init_tracker.sql
	\i ../history_tracker.sql
	
	CREATE SCHEMA myschema;
	\i create_tables.sql

	CREATE TABLE checkpoints
	(
		name character varying PRIMARY KEY,
		creation timestamp DEFAULT now()
	);



	SELECT plan(27);
	
	-- TEST EMPTY TABLE
	SELECT is(ht_init('myschema', 'mytable'), True, '*** Init history (empty table). ***');
	SELECT is(MAX(id), NULL, '   => Check if data table is empty.') FROM myschema.mytable;
	SELECT is(MAX(id), NULL, '   => Check if history table is empty.') FROM hist_tracker.myschema__mytable;
	
	CREATE TABLE checkpoint_empty_init AS SELECT * FROM myschema.mytable;
	INSERT INTO checkpoints VALUES ('checkpoint_empty_init');
	
	-- INSERT
	INSERT INTO myschema.mytable (aaa, bbb) VALUES (1, 'a');
	SELECT is(COUNT(*)::integer, 1, '   => INSERT data #1.') FROM myschema.mytable;
	SELECT results_eq(
		'SELECT id, aaa, bbb::text, time_start IS NULL, time_end IS NULL, id_hist
			FROM hist_tracker.myschema__mytable ORDER BY id_hist',
		'VALUES (1, 1, ''a'', False, True, 1)',
		'   => Check timestamp values in history table.'
		);
	CREATE TABLE checkpoint_empty_insert1 AS SELECT * FROM myschema.mytable;
	INSERT INTO checkpoints VALUES ('checkpoint_empty_insert1');
	
	INSERT INTO myschema.mytable (aaa, bbb) VALUES (2, 'b');
	INSERT INTO myschema.mytable (aaa, bbb) VALUES (3, 'c');
	INSERT INTO myschema.mytable (aaa, bbb) VALUES (4, 'd');
	SELECT is(COUNT(*)::integer, 4, '   => INSERT data #2.') FROM myschema.mytable;
	SELECT results_eq(
		'SELECT id, aaa, bbb::text, time_start IS NULL, time_end IS NULL, id_hist
			FROM hist_tracker.myschema__mytable ORDER BY id_hist',
		'VALUES (1, 1, ''a'', False, True, 1), (2, 2, ''b'', False, True, 2),
			(3, 3, ''c'', False, True, 3), (4, 4, ''d'', False, True, 4)',
		'   => Check timestamp values in history table.'
		);
	CREATE TABLE checkpoint_empty_insert2 AS SELECT * FROM myschema.mytable;
	INSERT INTO checkpoints VALUES ('checkpoint_empty_insert2');

	-- UPDATE
	UPDATE myschema.mytable SET aaa = 11 WHERE aaa = 1;
	SELECT is(COUNT(*)::integer, 4, '   => UPDATE data #1.') FROM myschema.mytable;
	SELECT results_eq(
		'SELECT id, aaa, bbb::text, time_start IS NULL, time_end IS NULL, time_end > time_start, id_hist
			FROM hist_tracker.myschema__mytable ORDER BY id_hist',
		'VALUES (1, 11, ''a'', False, True, NULL, 1), (2, 2, ''b'', False, True, NULL, 2),
			(3, 3, ''c'', False, True, NULL, 3), (4, 4, ''d'', False, True, NULL, 4),

			(1, 1, ''a'', False, False, True, 5)',
		'   => Check timestamp values in history table.'
		);
	CREATE TABLE checkpoint_empty_update1 AS SELECT * FROM myschema.mytable;
	INSERT INTO checkpoints VALUES ('checkpoint_empty_update1');

	UPDATE myschema.mytable SET aaa = 22 WHERE aaa = 2;
	UPDATE myschema.mytable SET aaa = 33 WHERE aaa = 3;
	UPDATE myschema.mytable SET aaa = 44 WHERE aaa = 4;
	SELECT is(COUNT(*)::integer, 4, '   => UPDATE data #2.') FROM myschema.mytable;
	SELECT results_eq(
		'SELECT id, aaa, bbb::text, time_start IS NULL, time_end IS NULL, time_end > time_start, id_hist
			FROM hist_tracker.myschema__mytable ORDER BY id_hist',
		'VALUES (1, 11, ''a'', False, True, NULL, 1), (2, 22, ''b'', False, True, NULL, 2),
			(3, 33, ''c'', False, True, NULL, 3), (4, 44, ''d'', False, True, NULL, 4),
			
			(1, 1, ''a'', False, False, True, 5), (2, 2, ''b'', False, False, True, 6),
			(3, 3, ''c'', False, False, True, 7), (4, 4, ''d'', False, False, True, 8)',
		'   => Check timestamp values in history table.'
		);
	CREATE TABLE checkpoint_empty_update2 AS SELECT * FROM myschema.mytable;
	INSERT INTO checkpoints VALUES ('checkpoint_empty_update2');


	-- DELETE
	DELETE FROM myschema.mytable WHERE aaa = 11;
	SELECT is(COUNT(*)::integer, 3, '   => DELETE data #1.') FROM myschema.mytable;
	SELECT results_eq(
		'SELECT id, aaa, bbb::text, time_start IS NULL, time_end IS NULL, time_end > time_start, id_hist
			FROM hist_tracker.myschema__mytable ORDER BY id_hist',
		'VALUES (1, 11, ''a'', False, False, True, 1), (2, 22, ''b'', False, True, NULL, 2),
			(3, 33, ''c'', False, True, NULL, 3), (4, 44, ''d'', False, True, NULL, 4),
			
			(1, 1, ''a'', False, False, True, 5), (2, 2, ''b'', False, False, True, 6),
			(3, 3, ''c'', False, False, True, 7), (4, 4, ''d'', False, False, True, 8)',
		'   => Check timestamp values in history table.'
		);
	CREATE TABLE checkpoint_empty_delete1 AS SELECT * FROM myschema.mytable;
	INSERT INTO checkpoints VALUES ('checkpoint_empty_delete1');

	DELETE FROM myschema.mytable WHERE aaa = 22;
	DELETE FROM myschema.mytable WHERE aaa = 33;
	DELETE FROM myschema.mytable WHERE aaa = 44;
	SELECT is(COUNT(*)::integer, 0, '   => DELETE data #2.') FROM myschema.mytable;
	SELECT results_eq(
		'SELECT id, aaa, bbb::text, time_start IS NULL, time_end IS NULL, time_end > time_start, id_hist
			FROM hist_tracker.myschema__mytable ORDER BY id_hist',
		'VALUES (1, 11, ''a'', False, False, True, 1), (2, 22, ''b'', False, False, True, 2),
			(3, 33, ''c'', False, False, True, 3), (4, 44, ''d'', False, False, True, 4),
			
			(1, 1, ''a'', False, False, True, 5), (2, 2, ''b'', False, False, True, 6),
			(3, 3, ''c'', False, False, True, 7), (4, 4, ''d'', False, False, True, 8)',
		'   => Check timestamp values in history table.'
		);
	CREATE TABLE checkpoint_empty_delete2 AS SELECT * FROM myschema.mytable;
	INSERT INTO checkpoints VALUES ('checkpoint_empty_delete2');


	-- TEST CHECKPOINTS
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
	
	-- TODO: test diff functions
	
	-- clean 
	SELECT is(ht_drop('myschema', 'mytable'), True, '*** Drop history (empty table). ***');
	DROP TABLE myschema.mytable;



	-- TEST POPULATED TABLE
	\i create_tables.sql
	
	INSERT INTO myschema.mytable (aaa, bbb) VALUES (1, 'a');
	INSERT INTO myschema.mytable (aaa, bbb) VALUES (2, 'b');
	INSERT INTO myschema.mytable (aaa, bbb) VALUES (3, 'c');
	INSERT INTO myschema.mytable (aaa, bbb) VALUES (4, 'd');
	
	SELECT is(ht_init('myschema', 'mytable'), True, '*** Init history (populated table). ***');
	SELECT is(MAX(id), 4, '   => Check if data table has data.') FROM myschema.mytable;
	SELECT results_eq(
		'SELECT id, aaa, bbb::text, time_start IS NULL, time_end IS NULL, id_hist
			FROM hist_tracker.myschema__mytable ORDER BY id_hist',
		'VALUES (1, 1, ''a'', False, True, 1), (2, 2, ''b'', False, True, 2),
			(3, 3, ''c'', False, True, 3), (4, 4, ''d'', False, True, 4)',
		'   => Check timestamp values in history table.'
		);


	SELECT * FROM finish();
--ROLLBACK;
