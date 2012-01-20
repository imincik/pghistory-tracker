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
	\i drop_schema.sql

SELECT plan(1);

SELECT hasnt_schema(
	'history_tracker',
	'Check if initial schema has gone'
);

SELECT * FROM finish();
ROLLBACK;
