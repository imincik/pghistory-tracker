--DROP FUNCTION gis.G_GetTableFields(text, text);
CREATE OR REPLACE FUNCTION gis.G_Get_Table_Fields(dbschema text, dbtable text)
	RETURNS text AS
$BODY$

dbschema = args[0]
dbtable = args[1]
vars = {'dbschema': dbschema, 'dbtable': dbtable} 

sql = """
SELECT a.attnum AS ordinal_position,
	a.attname AS column_name,
	t.typname AS data_type,
	a.attlen AS char_max_len,
	a.atttypmod AS modifier,
	a.attnotnull AS notnull,
	a.atthasdef AS hasdefault,
	adef.adsrc AS default_value
FROM pg_class c
JOIN pg_attribute a ON a.attrelid = c.oid
JOIN pg_type t ON a.atttypid = t.oid
JOIN pg_namespace nsp ON c.relnamespace = nsp.oid
LEFT JOIN pg_attrdef adef ON adef.adrelid = a.attrelid AND adef.adnum = a.attnum
WHERE
	nspname = '%(dbschema)s' AND c.relname = '%(dbtable)s' AND
	a.attnum > 0
ORDER BY a.attnum;
""" % vars
ret = plpy.execute(sql)

if len(ret):
	table_fields = []
	for r in ret:
		table_fields.append(r['column_name'])
		
return ','.join(f for f in table_fields)

$BODY$
LANGUAGE 'plpythonu' VOLATILE
