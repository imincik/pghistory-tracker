--TODO:
-- ht_log
-- ht_difftotime
-- ht_difftotag

-- CREATE SCHEMA
CREATE SCHEMA hist_tracker;




-- CREATE TABLES
CREATE TABLE hist_tracker.tags (
	id serial PRIMARY KEY,
	dbschema character varying,
	dbtable character varying,
	dbuser character varying,
	time_tag timestamp,
	changes_count integer,
	message character varying
);




-- HT_GetTableFields
CREATE OR REPLACE FUNCTION HT_GetTableFields(dbschema text, dbtable text)
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
LANGUAGE 'plpythonu' VOLATILE;




-- HT_Create_DiffType
CREATE OR REPLACE FUNCTION HT_Create_DiffType(dbschema text, dbtable text)
	RETURNS text AS
$BODY$

dbschema = args[0]
dbtable = args[1]
vars = {'dbschema': dbschema, 'dbtable': dbtable} 

sql_type_schema = """
	SELECT column_name, udt_name FROM information_schema.columns
		WHERE table_schema = '%(dbschema)s' AND table_name = '%(dbtable)s'
		ORDER BY ordinal_position;
""" % vars
ret_type_schema = plpy.execute(sql_type_schema)

if len(ret_type_schema):
	type_schema = []
	for r in ret_type_schema:
		type_schema.append('%s %s' % (r['column_name'], r['udt_name']))
		
vars['type_schema_def'] = ','.join(f for f in type_schema)

sql_create_type = """
	CREATE TYPE %(dbschema)s.ht_%(dbtable)s_difftype AS 
		(operation character(1), %(type_schema_def)s);
""" % vars
plpy.execute(sql_create_type)

return True

$BODY$
LANGUAGE 'plpythonu' VOLATILE;




-- HT_CreateHistory
CREATE OR REPLACE FUNCTION HT_CreateHistory(dbschema text, dbtable text)
	RETURNS integer AS
$BODY$

from datetime import datetime

dbschema = args[0]
dbtable = args[1]
dbuser = plpy.execute("SELECT current_user")[0]['current_user']
table_fields = plpy.execute("SELECT HT_GetTableFields('%s', '%s') AS table_fields" % (dbschema, dbtable))[0]['table_fields']
pkey = plpy.execute("SELECT column_name FROM information_schema.key_column_usage \
	WHERE table_schema = '%s' AND table_name = '%s'" % (dbschema, dbtable))[0]['column_name']
dtime = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

vars = {'dbschema': dbschema, 'dbtable': dbtable, 'dbuser': dbuser, 'table_fields': table_fields, 'pkey': pkey, 'dtime': dtime} 


#HISTORY TAB
sql_history_tab = """
	CREATE TABLE hist_tracker.%(dbschema)s__%(dbtable)s AS SELECT * FROM %(dbschema)s.%(dbtable)s;

	ALTER TABLE hist_tracker.%(dbschema)s__%(dbtable)s ADD time_start timestamp, ADD time_end timestamp, 
		ADD dbuser character varying, ADD id_hist serial;
	ALTER TABLE hist_tracker.%(dbschema)s__%(dbtable)s ADD PRIMARY KEY (id_hist);
	
	CREATE INDEX idx_%(dbschema)s__%(dbtable)s_id_hist
		ON hist_tracker.%(dbschema)s__%(dbtable)s
		USING btree (id_hist);
	CREATE INDEX idx_%(dbschema)s__%(dbtable)s_%(pkey)s
		ON hist_tracker.%(dbschema)s__%(dbtable)s
		USING btree (%(pkey)s);
	
	COMMENT ON TABLE hist_tracker.%(dbschema)s__%(dbtable)s IS 
		'GIS history: %(dbschema)s.%(dbtable)s, Created: %(dtime)s, Creator: %(dbuser)s.';
""" % vars
plpy.execute(sql_history_tab)

sql_history_tab2 = """
	UPDATE hist_tracker.%(dbschema)s__%(dbtable)s SET time_start = now();
""" % vars
plpy.execute(sql_history_tab2)

plpy.execute("INSERT INTO hist_tracker.tags (dbschema, dbtable, dbuser, time_tag, message, changes_count) \
	VALUES ('%(dbschema)s', '%(dbtable)s', '%(dbuser)s', current_timestamp, 'History init.', 0)" % vars)


#AtTime function 
sql_attime_funct = """
	CREATE OR REPLACE FUNCTION %(dbschema)s.%(dbtable)s_AtTime(timestamp)
	RETURNS SETOF %(dbschema)s.%(dbtable)s AS
	$$
	SELECT %(table_fields)s FROM hist_tracker.%(dbschema)s__%(dbtable)s WHERE
		( SELECT CASE WHEN time_end IS NULL THEN (time_start <= $1) ELSE (time_start <= $1 AND time_end > $1) END );
	$$
	LANGUAGE 'SQL';
""" % vars
plpy.execute(sql_attime_funct)

sql_create_difftype = "SELECT HT_Create_DiffType('%(dbschema)s', '%(dbtable)s');" % vars
plpy.execute(sql_create_difftype)


#DiffToTime function
sql_difftotime_funct = """
	CREATE OR REPLACE FUNCTION %(dbschema)s.%(dbtable)s_DiffToTime(difftime timestamp)
	RETURNS SETOF %(dbschema)s.ht_%(dbtable)s_difftype AS
	$$
	BEGIN
		IF difftime > (SELECT MIN(time_tag) FROM hist_tracker.tags WHERE dbschema = '%(dbschema)s' AND dbtable = '%(dbtable)s') THEN
			RETURN QUERY
				SELECT '+'::character(1) AS operation, * FROM %(dbschema)s.%(dbtable)s WHERE %(pkey)s IN
				(SELECT DISTINCT %(pkey)s FROM hist_tracker.%(dbschema)s__%(dbtable)s   
				WHERE time_start > difftime AND time_end IS NULL)

				UNION ALL

				SELECT '-'::character(1) AS operation, * FROM %(dbschema)s.%(dbtable)s_AtTime(difftime) WHERE %(pkey)s NOT IN
				(SELECT DISTINCT %(pkey)s FROM %(dbschema)s.%(dbtable)s);
		ELSE
			RAISE WARNING 'Can not diff to time before history was created.';
			RETURN;
		END IF;
	END;
	$$
	LANGUAGE 'plpgsql';
""" % vars
plpy.execute(sql_difftotime_funct)


#INSERT
sql_insert_funct = """
	CREATE OR REPLACE FUNCTION %(dbschema)s.tg_%(dbtable)s_insert()
	RETURNS TRIGGER AS
	$$
	BEGIN
		INSERT INTO hist_tracker.%(dbschema)s__%(dbtable)s VALUES (NEW.*);	
	RETURN NEW;
	END;
	$$
	LANGUAGE 'plpgsql';

	CREATE TRIGGER tg_%(dbtable)s_insert BEFORE INSERT ON %(dbschema)s.%(dbtable)s
	FOR EACH ROW EXECUTE PROCEDURE %(dbschema)s.tg_%(dbtable)s_insert();

	
	
	CREATE OR REPLACE FUNCTION hist_tracker.tg_%(dbschema)s__%(dbtable)s_insert()
	RETURNS trigger AS
	$$
	BEGIN
	IF NEW.time_start IS NULL THEN
		NEW.time_start = now();
		NEW.time_end = null;
		NEW.dbuser = current_user;
	END IF;
  	RETURN NEW;
	END;
	$$
	LANGUAGE 'plpgsql';

	CREATE TRIGGER tg_%(dbschema)s__%(dbtable)s_insert BEFORE INSERT ON hist_tracker.%(dbschema)s__%(dbtable)s
	FOR EACH ROW EXECUTE PROCEDURE hist_tracker.tg_%(dbschema)s__%(dbtable)s_insert();
	""" % vars
plpy.execute(sql_insert_funct)


#UPDATE
sql_update_vars = vars
sql_update_vars['sql_update_str1'] = ','.join('%s = NEW.%s' % (f, f) for f in table_fields.split(','))
sql_update_vars['sql_update_str2'] = ','.join('OLD.%s' % (f) for f in table_fields.split(','))
sql_update_funct = """
	CREATE OR REPLACE FUNCTION %(dbschema)s.tg_%(dbtable)s_update()
	RETURNS TRIGGER AS
	$$
	BEGIN
		UPDATE hist_tracker.%(dbschema)s__%(dbtable)s SET %(sql_update_str1)s WHERE %(pkey)s = NEW.%(pkey)s;
	RETURN NEW;
	END;
	$$
	LANGUAGE 'plpgsql';

	CREATE TRIGGER tg_%(dbtable)s_update BEFORE UPDATE ON %(dbschema)s.%(dbtable)s
	FOR EACH ROW EXECUTE PROCEDURE %(dbschema)s.tg_%(dbtable)s_update();



	CREATE OR REPLACE FUNCTION hist_tracker.tg_%(dbschema)s__%(dbtable)s_update()
	RETURNS TRIGGER AS
	$$
	BEGIN
	IF OLD.time_end IS NOT NULL THEN
	RETURN NULL;
	END IF;
	IF NEW.time_end IS NULL THEN
	INSERT INTO hist_tracker.%(dbschema)s__%(dbtable)s
		(%(table_fields)s, time_start, time_end, dbuser) VALUES (%(sql_update_str2)s, OLD.time_start, current_timestamp, current_user);
	NEW.time_start = current_timestamp;
	END IF;
	RETURN NEW;
	END;
	$$
	LANGUAGE 'plpgsql';
	
	CREATE TRIGGER tg_%(dbschema)s__%(dbtable)s_update BEFORE UPDATE ON hist_tracker.%(dbschema)s__%(dbtable)s
	FOR EACH ROW EXECUTE PROCEDURE hist_tracker.tg_%(dbschema)s__%(dbtable)s_update();
""" % sql_update_vars
plpy.execute(sql_update_funct)


#DELETE
sql_delete_funct = """
	CREATE OR REPLACE FUNCTION %(dbschema)s.tg_%(dbtable)s_delete()
	RETURNS TRIGGER AS
	$$
	BEGIN
		DELETE FROM hist_tracker.%(dbschema)s__%(dbtable)s WHERE %(pkey)s = OLD.%(pkey)s;
	RETURN OLD;
	END;
	$$
	LANGUAGE 'plpgsql';

	CREATE TRIGGER tg_%(dbtable)s_delete BEFORE DELETE ON %(dbschema)s.%(dbtable)s
	FOR EACH ROW EXECUTE PROCEDURE %(dbschema)s.tg_%(dbtable)s_delete();


	CREATE RULE %(dbschema)s__%(dbtable)s_del AS ON DELETE TO hist_tracker.%(dbschema)s__%(dbtable)s
	DO INSTEAD UPDATE hist_tracker.%(dbschema)s__%(dbtable)s SET time_end = current_timestamp, dbuser = current_user
		WHERE id_hist = OLD.id_hist AND time_end IS NULL;
""" % vars
plpy.execute(sql_delete_funct)
return 1

$BODY$
LANGUAGE 'plpythonu' VOLATILE;




-- HT_RemoveHistory
CREATE OR REPLACE FUNCTION HT_RemoveHistory(dbschema text, dbtable text)
	RETURNS integer AS
$BODY$

dbschema = args[0]
dbtable = args[1]

vars = {'dbschema': dbschema, 'dbtable': dbtable} 

#INSERT
sql_insert_funct = """
	DROP TRIGGER tg_%(dbschema)s__%(dbtable)s_insert ON hist_tracker.%(dbschema)s__%(dbtable)s;
	DROP FUNCTION hist_tracker.tg_%(dbschema)s__%(dbtable)s_insert();

	DROP TRIGGER tg_%(dbtable)s_insert ON %(dbschema)s.%(dbtable)s;
	DROP FUNCTION %(dbschema)s.tg_%(dbtable)s_insert();
	""" % vars
plpy.execute(sql_insert_funct)

#UPDATE
sql_update_funct = """
	DROP TRIGGER tg_%(dbschema)s__%(dbtable)s_update ON hist_tracker.%(dbschema)s__%(dbtable)s;	
	DROP FUNCTION hist_tracker.tg_%(dbschema)s__%(dbtable)s_update();
	
	DROP TRIGGER tg_%(dbtable)s_update ON %(dbschema)s.%(dbtable)s;
	DROP FUNCTION %(dbschema)s.tg_%(dbtable)s_update();
""" % vars
plpy.execute(sql_update_funct)

#DELETE
sql_delete_funct = """
	DROP RULE %(dbschema)s__%(dbtable)s_del ON hist_tracker.%(dbschema)s__%(dbtable)s;
	
	DROP TRIGGER tg_%(dbtable)s_delete ON %(dbschema)s.%(dbtable)s;
	DROP FUNCTION %(dbschema)s.tg_%(dbtable)s_delete();
""" % vars
plpy.execute(sql_delete_funct)

#layer functions 
sql_lay_funct = """
	DROP FUNCTION %(dbschema)s.%(dbtable)s_AtTime(timestamp);
	DROP FUNCTION %(dbschema)s.%(dbtable)s_DiffToTime(timestamp);
""" % vars
plpy.execute(sql_lay_funct)

#types 
sql_lay_funct = """
	DROP TYPE %(dbschema)s.ht_%(dbtable)s_difftype;
""" % vars
plpy.execute(sql_lay_funct)


#HISTORY TAB
sql_history_tab = """
	DROP TABLE hist_tracker.%(dbschema)s__%(dbtable)s;
""" % vars
plpy.execute(sql_history_tab)

return 1

$BODY$
LANGUAGE 'plpythonu' VOLATILE;




-- HT_Tag
CREATE OR REPLACE FUNCTION HT_Tag(dbschema text, dbtable text, message text)
	RETURNS boolean AS
$BODY$

dbschema = args[0]
dbtable = args[1]
message = args[2]

pkey = plpy.execute("SELECT column_name FROM information_schema.key_column_usage \
	WHERE table_schema = '%s' AND table_name = '%s'" % (dbschema, dbtable))[0]['column_name']

vars = {'dbschema': dbschema, 'dbtable': dbtable, 'message': message, 'pkey': pkey} 

sql_table_exists = """
	SELECT COUNT(*) AS count FROM information_schema.tables
		WHERE table_schema = '%(dbschema)s' AND table_name = '%(dbtable)s' AND 
		table_type = 'BASE TABLE';
""" % vars
table_exists = plpy.execute(sql_table_exists)

time_last_tag = plpy.execute("SELECT MAX(time_tag) AS time_last_tag FROM hist_tracker.tags WHERE \
	dbschema = '%(dbschema)s' AND dbtable = '%(dbtable)s';" % vars)
vars['time_last_tag'] = time_last_tag[0]['time_last_tag']

if table_exists[0]['count'] == 1:
	sql_changes_count = """	SELECT COUNT(*) AS count FROM (
				SELECT * FROM %(dbschema)s.%(dbtable)s WHERE %(pkey)s IN
					(SELECT DISTINCT %(pkey)s FROM hist_tracker.%(dbschema)s__%(dbtable)s   
						WHERE time_start > '%(time_last_tag)s' AND time_end IS NULL)

				UNION ALL

				SELECT * FROM %(dbschema)s.%(dbtable)s_AtTime('%(time_last_tag)s') WHERE %(pkey)s NOT IN
					(SELECT DISTINCT %(pkey)s FROM %(dbschema)s.%(dbtable)s)

				) AS foo;
	""" % vars
	changes_count = plpy.execute(sql_changes_count)
	
	vars['changes_count'] = changes_count[0]['count']
	if vars['changes_count'] > 0:
		plpy.execute("INSERT INTO hist_tracker.tags (dbschema, dbtable, dbuser, time_tag, changes_count, message) \
			VALUES ('%(dbschema)s', '%(dbtable)s', current_user, current_timestamp, '%(changes_count)s', '%(message)s');" % vars)
		plpy.info('I: Tag created for %(changes_count)s changes.' % vars)
		return True
	else:
		plpy.warning('W: Nothing changed since last tag.')
		return False
else:
	plpy.warning('W: Table does not exists.')
	return False

$BODY$
LANGUAGE 'plpythonu' VOLATILE;

-- # vim: set syntax=python ts=8 sts=8 sw=8 noet: 
