-- _HT_GetTableFields(text, text)
-- TODO: return array
CREATE OR REPLACE FUNCTION _HT_GetTableFields(dbschema text, dbtable text)
	RETURNS text AS
$$
DECLARE
	sql text;
	ret text;

BEGIN
	-- TODO: array_agg does not exists in PostgreSQL 8.3
	sql :=
	'SELECT array_to_string(array_agg(column_name::text), '','') FROM 
		(SELECT column_name FROM information_schema.columns
			WHERE table_schema = ''' || quote_ident(dbschema) || '''
			AND table_name = ''' || quote_ident(dbtable) || '''
			ORDER BY ordinal_position) AS foo';

	EXECUTE sql INTO ret;
	
	RETURN ret;
END;
$$
LANGUAGE plpgsql VOLATILE;



-- _HT_GetTablePkey(text, text)
CREATE OR REPLACE FUNCTION _HT_GetTablePkey(dbschema text, dbtable text)
	RETURNS text AS
$$
DECLARE
	sql text;
	ret text;

BEGIN
	sql := 'SELECT column_name FROM information_schema.key_column_usage
		WHERE table_schema = ''' || quote_ident(dbschema) || '''
		AND table_name = ''' || quote_ident(dbtable) || '''';

	EXECUTE sql INTO ret;

	RETURN ret;
END;
$$
LANGUAGE plpgsql VOLATILE;





-- _HT_TableExists(text, text)
CREATE OR REPLACE FUNCTION _HT_TableExists(dbschema text, dbtable text)
	RETURNS boolean AS
$$
DECLARE
	sql text;
	cnt integer;

BEGIN
	sql := 'SELECT COUNT(*) FROM information_schema.tables
		WHERE table_schema = ''' || quote_ident(dbschema) || ''' 
		AND table_name = ''' || quote_ident(dbtable) || '''
		AND table_type = ''BASE TABLE''';

	EXECUTE sql INTO cnt;

	IF cnt > 0 THEN
		RETURN True;
	ELSE
		RETURN False;
	END IF;
END;
$$
LANGUAGE plpgsql VOLATILE;




-- _HT_CreateDiffType
CREATE OR REPLACE FUNCTION _HT_CreateDiffType(dbschema text, dbtable text)
	RETURNS boolean AS
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




-- HT_Init
-- TODO: warn when initing already enabled table (upgrades)
CREATE OR REPLACE FUNCTION HT_Init(dbschema text, dbtable text)
	RETURNS boolean AS
$BODY$

from datetime import datetime

dbschema = args[0]
dbtable = args[1]
dbuser = plpy.execute("SELECT current_user")[0]['current_user']
table_fields = plpy.execute("SELECT _HT_GetTableFields('%s', '%s') AS table_fields" % (dbschema, dbtable))[0]['table_fields']
pkey = plpy.execute("SELECT _HT_GetTablePkey('%s', '%s') AS pkey" % (dbschema, dbtable))[0]['pkey']
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


sql_history_tab2 = """
	UPDATE hist_tracker.%(dbschema)s__%(dbtable)s SET time_start = now();
	
	INSERT INTO hist_tracker.tags (id_tag, dbschema, dbtable, dbuser, time_tag, message, changes_count)
		VALUES (1, '%(dbschema)s', '%(dbtable)s', '%(dbuser)s', current_timestamp, 'History init.', 0);
""" % vars

sql_create_difftype = "SELECT _HT_CreateDiffType('%(dbschema)s', '%(dbtable)s');" % vars

if plpy.execute("SELECT _HT_TableExists('hist_tracker', '%(dbschema)s__%(dbtable)s') AS tableexists" % vars)[0]['tableexists'] is False:
	plpy.execute(sql_history_tab)
	plpy.execute(sql_history_tab2)
	plpy.execute(sql_create_difftype)


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





#Diff(timestamp) function
sql_difftotime_funct = """
	CREATE OR REPLACE FUNCTION %(dbschema)s.%(dbtable)s_Diff(difftime timestamp)
	RETURNS SETOF %(dbschema)s.ht_%(dbtable)s_difftype AS
	$$
	BEGIN
		IF difftime >= (SELECT MIN(time_tag) FROM hist_tracker.tags WHERE dbschema = '%(dbschema)s' AND dbtable = '%(dbtable)s') THEN
			RETURN QUERY
				SELECT ':'::character(1) AS operation, * FROM %(dbschema)s.%(dbtable)s 
				WHERE %(pkey)s IN
					(SELECT DISTINCT %(pkey)s FROM hist_tracker.%(dbschema)s__%(dbtable)s   
						WHERE time_start > difftime AND time_end IS NULL)
				AND %(pkey)s IN
					(SELECT DISTINCT ON (%(pkey)s) %(pkey)s FROM hist_tracker.%(dbschema)s__%(dbtable)s   
						WHERE time_start <= difftime ORDER BY %(pkey)s, time_start DESC)

				UNION ALL
				
				SELECT '+'::character(1) AS operation, * FROM %(dbschema)s.%(dbtable)s 
				WHERE %(pkey)s IN
					(SELECT DISTINCT %(pkey)s FROM hist_tracker.%(dbschema)s__%(dbtable)s   
						WHERE time_start > difftime AND time_end IS NULL)
				AND %(pkey)s NOT IN
					(SELECT DISTINCT ON (%(pkey)s) %(pkey)s FROM hist_tracker.%(dbschema)s__%(dbtable)s   
						WHERE time_start <= difftime ORDER BY %(pkey)s, time_start DESC)

				UNION ALL

				SELECT '-'::character(1) AS operation, * FROM %(dbschema)s.%(dbtable)s_AtTime(difftime) 
				WHERE %(pkey)s NOT IN
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

#Diff() function
sql_difftotime_funct = """
	CREATE OR REPLACE FUNCTION %(dbschema)s.%(dbtable)s_Diff()
	RETURNS SETOF %(dbschema)s.ht_%(dbtable)s_difftype AS
	$$
	DECLARE
		difftime timestamp;
		ret_row record;
	BEGIN
		difftime := (SELECT MAX(time_tag) FROM hist_tracker.tags WHERE dbschema = '%(dbschema)s' AND dbtable = '%(dbtable)s');
		FOR ret_row IN SELECT * FROM %(dbschema)s.%(dbtable)s_Diff(difftime) LOOP
			RETURN NEXT ret_row;
		END LOOP;
		RETURN;
	END;
	$$
	LANGUAGE 'plpgsql';
""" % vars
plpy.execute(sql_difftotime_funct)

#DiffToTag function
sql_difftotime_funct = """
	CREATE OR REPLACE FUNCTION %(dbschema)s.%(dbtable)s_DiffToTag(difftag integer)
	RETURNS SETOF %(dbschema)s.ht_%(dbtable)s_difftype AS
	$$
	DECLARE
		difftime timestamp;
		ret_row record;
	BEGIN
		IF difftag <= (SELECT MAX(id_tag) FROM hist_tracker.tags WHERE dbschema = '%(dbschema)s' AND dbtable = '%(dbtable)s') THEN
			difftime := (SELECT time_tag FROM hist_tracker.tags WHERE dbschema = '%(dbschema)s' AND dbtable = '%(dbtable)s' AND id_tag = difftag);
			FOR ret_row IN SELECT * FROM %(dbschema)s.%(dbtable)s_Diff(difftime) LOOP
				RETURN NEXT ret_row;
			END LOOP;
			RETURN;
	
		ELSE
			RAISE WARNING 'Tag does not exists.';
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

	DROP TRIGGER IF EXISTS tg_%(dbtable)s_insert ON %(dbschema)s.%(dbtable)s;
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

	DROP TRIGGER IF EXISTS tg_%(dbschema)s__%(dbtable)s_insert ON hist_tracker.%(dbschema)s__%(dbtable)s;
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

	DROP TRIGGER IF EXISTS tg_%(dbtable)s_update ON %(dbschema)s.%(dbtable)s;
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
	
	DROP TRIGGER IF EXISTS tg_%(dbschema)s__%(dbtable)s_update ON hist_tracker.%(dbschema)s__%(dbtable)s;
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

	DROP TRIGGER IF EXISTS tg_%(dbtable)s_delete ON %(dbschema)s.%(dbtable)s;
	CREATE TRIGGER tg_%(dbtable)s_delete BEFORE DELETE ON %(dbschema)s.%(dbtable)s
	FOR EACH ROW EXECUTE PROCEDURE %(dbschema)s.tg_%(dbtable)s_delete();

	DROP RULE IF EXISTS %(dbschema)s__%(dbtable)s_del ON hist_tracker.%(dbschema)s__%(dbtable)s;
	CREATE RULE %(dbschema)s__%(dbtable)s_del AS ON DELETE TO hist_tracker.%(dbschema)s__%(dbtable)s
	DO INSTEAD UPDATE hist_tracker.%(dbschema)s__%(dbtable)s SET time_end = current_timestamp, dbuser = current_user
		WHERE id_hist = OLD.id_hist AND time_end IS NULL;
""" % vars
plpy.execute(sql_delete_funct)

return True

$BODY$
LANGUAGE 'plpythonu' VOLATILE;




-- HT_Drop
CREATE OR REPLACE FUNCTION HT_Drop(dbschema text, dbtable text)
	RETURNS boolean AS
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
	DROP FUNCTION %(dbschema)s.%(dbtable)s_Diff();
	DROP FUNCTION %(dbschema)s.%(dbtable)s_AtTime(timestamp);
	DROP FUNCTION %(dbschema)s.%(dbtable)s_Diff(timestamp);
	DROP FUNCTION %(dbschema)s.%(dbtable)s_DiffToTag(integer);
""" % vars
plpy.execute(sql_lay_funct)

#types 
sql_lay_funct = """
	DROP TYPE %(dbschema)s.ht_%(dbtable)s_difftype;
""" % vars
plpy.execute(sql_lay_funct)

#hist_tracker.tags
plpy.execute("DELETE FROM hist_tracker.tags WHERE dbschema = '%(dbschema)s' AND dbtable = '%(dbtable)s';" % vars)

#HISTORY TAB
sql_history_tab = """
	DROP TABLE hist_tracker.%(dbschema)s__%(dbtable)s;
""" % vars
plpy.execute(sql_history_tab)

return True

$BODY$
LANGUAGE 'plpythonu' VOLATILE;




-- HT_Tag
-- TODO: rewrite to plpgsql
CREATE OR REPLACE FUNCTION HT_Tag(dbschema text, dbtable text, message text)
	RETURNS boolean AS
$BODY$

dbschema = args[0]
dbtable = args[1]
message = args[2]

pkey = plpy.execute("SELECT _HT_GetTablePkey('%s', '%s') AS pkey" % (dbschema, dbtable))[0]['pkey']

vars = {'dbschema': dbschema, 'dbtable': dbtable, 'message': message, 'pkey': pkey} 

time_last_tag = plpy.execute("SELECT MAX(time_tag) AS time_last_tag FROM hist_tracker.tags WHERE \
	dbschema = '%(dbschema)s' AND dbtable = '%(dbtable)s';" % vars)
vars['time_last_tag'] = time_last_tag[0]['time_last_tag']

if plpy.execute("SELECT _HT_TableExists('%(dbschema)s', '%(dbtable)s') AS tableexists" % vars)[0]['tableexists'] is True:
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
		plpy.execute("INSERT INTO hist_tracker.tags (id_tag, dbschema, dbtable, dbuser, time_tag, changes_count, message) \
			VALUES (_HT_NextTagValue('%(dbschema)s', '%(dbtable)s'), \
				'%(dbschema)s', '%(dbtable)s', current_user, current_timestamp, '%(changes_count)s', '%(message)s');" % vars)
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



--HT_Log
CREATE OR REPLACE FUNCTION HT_Log(text, text)
	RETURNS SETOF hist_tracker.tags AS
$$
	SELECT * FROM hist_tracker.tags WHERE dbschema = $1 AND dbtable = $2 ORDER BY id DESC;
$$
LANGUAGE 'SQL';

CREATE OR REPLACE FUNCTION HT_Log()
	RETURNS SETOF hist_tracker.tags AS
$$
	SELECT * FROM hist_tracker.tags ORDER BY id DESC;
$$
LANGUAGE 'SQL';




-- # vim: set syntax=python ts=4 sts=4 sw=4 noet: 
