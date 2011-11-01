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
	\i ../init_tracker.sql

SELECT plan(2);

-- Test if schemas exists
SELECT schemas_are(
	ARRAY['public', 'history_tracker'],
	'Check if initial schemas exists'
);

-- Test if tables exists
SELECT tables_are(
	'history_tracker',
	ARRAY['tags'],
	'Check if core tables exists'
);

SELECT * FROM finish();
ROLLBACK;
