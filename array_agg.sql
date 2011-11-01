CREATE AGGREGATE aggarray (
	basetype = anyelement, 
	sfunc = array_append,
	stype = anyarray
);
