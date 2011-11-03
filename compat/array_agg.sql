-- array_agg for PostgreSQL <= 8.3
CREATE AGGREGATE array_agg (
	basetype = anyelement, 
	sfunc = array_append,
	stype = anyarray
);
