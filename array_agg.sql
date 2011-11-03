CREATE AGGREGATE array_agg (
	basetype = anyelement, 
	sfunc = array_append,
	stype = anyarray
);
