#!/usr/bin/python


import sys
import psycopg2
import psycopg2.extras


conn_string = sys.argv[1]
dbschema = sys.argv[2]
dbtable = sys.argv[3]
tag = sys.argv[4]


try:
	conn = psycopg2.connect(conn_string)
except:
	print "E: Unable to connect to the database."
	sys.exit(1)


def _exec_sql(sql):
	#print 'D: SQL: %s' % sql.replace('\t', ' ')
	cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)
	cur.execute(sql)
	return cur

def _quote_str(val, quotation = 2):
	if quotation == 2:
		q = '"'
	else:
		q = "'"
	
	if val == 'NULL':
		return 'NULL'
	else:
		return '%s%s%s' % (q, val, q)

def _delete_cmd(pkey_val):
	print """DELETE FROM "%s"."%s" WHERE "%s" = '%s';""" % (dbschema, dbtable, pkey, pkey_val)

def _update_cmd(fields, vals, val_pkey):
	field_str = ", ".join('"%s"' % f for f in fields)
	val_str = ", ".join("%s" % _quote_str(v, 1) for v in vals)

	print """UPDATE "%s"."%s" SET (%s) = (%s) WHERE "%s" = %s;""" % (dbschema, dbtable, 
			field_str, val_str, pkey, val_pkey)

def _insert_cmd(fields, vals):
	field_str = ", ".join('"%s"' % f for f in fields)
	val_str = ", ".join("%s" % _quote_str(v, 1) for v in vals)

	print """INSERT INTO "%s"."%s" (%s) VALUES (%s);""" % (dbschema, dbtable, field_str, val_str)


if __name__ == "__main__":
	
	# test if all changes closed in tag
	if _exec_sql('SELECT * FROM %s.%s_Diff() LIMIT 1' % (dbschema, dbtable)).fetchone():
		print "W: Unclosed changes in table. Run 'HT_Tag', then try again."
		sys.exit(1)

	#get table primary key
	pkey = _exec_sql("SELECT _HT_GetTablePkey('%s', '%s') AS pkey \
			LIMIT 1" % (dbschema, dbtable)).fetchone()['pkey']

	#get table fields
	fields = _exec_sql("SELECT * FROM %s.%s LIMIT 1" % (dbschema, dbtable)).fetchone().keys()
	
	
	#start transaction
	print 'BEGIN;'
	
	#DELETE
	diff_delete = _exec_sql("SELECT * FROM %s.%s_DiffToTag(%s) \
			WHERE operation = '-'" % (dbschema, dbtable, tag)).fetchall()
	
	print '\n-- DELETE'
	for diff_row in diff_delete:
		_delete_cmd(diff_row[pkey])
	
	
	#UPDATE
	diff_update = _exec_sql("SELECT * FROM %s.%s_DiffToTag(%s) \
			WHERE operation = ':'" % (dbschema, dbtable, tag)).fetchall()
	
	print '\n-- UPDATE'
	for diff_row in diff_update:
		vals = []
		for field in fields:
			if diff_row[field] is not None:
				vals.append(str(diff_row[field]))
			else:
				vals.append('NULL')
		
		_update_cmd(fields, vals, diff_row[pkey])
	
	
	#INSERT
	diff_insert = _exec_sql("SELECT * FROM %s.%s_DiffToTag(%s) \
			WHERE operation = '+'" % (dbschema, dbtable, tag)).fetchall()
	
	print '\n-- INSERT'
	for diff_row in diff_insert:
		vals = []
		for field in fields:
			if diff_row[field] is not None:
				vals.append(str(diff_row[field]))
			else:
				vals.append('NULL')
	
		_insert_cmd(fields, vals)


	#finish transaction
	print '\nEND;'
