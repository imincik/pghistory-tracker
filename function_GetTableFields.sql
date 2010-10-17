CREATE OR REPLACE FUNCTION SV_GetTableFields(dbschema text, dbtable text)
	RETURNS text AS
$BODY$

dbschema = args[0]
dbtable = args[1]
vars = {'dbschema': dbschema, 'dbtable': dbtable} 

sql = """
SELECT column_name FROM information_schema.columns
	WHERE table_schema = '%(dbschema)s' AND table_name = '%(dbtable)s'
	ORDER BY ordinal_position;
""" % vars
ret = plpy.execute(sql)

if len(ret):
	table_fields = []
	for r in ret:
		table_fields.append(r['column_name'])
		
return ','.join(f for f in table_fields)

$BODY$
LANGUAGE 'plpythonu' VOLATILE
