-- HT_Version()
CREATE OR REPLACE FUNCTION HT_Version()
	RETURNS text AS 'SELECT ''0.1-beta1''::text AS version;'
LANGUAGE SQL;
COMMENT ON FUNCTION HT_Version() IS
	'HT: Get version. USAGE: HT_Version()';




-- _HT_GetTableFields(text, text)
-- TODO: return array
CREATE OR REPLACE FUNCTION _HT_GetTableFields(dbschema text, dbtable text)
	RETURNS text AS
$$
DECLARE
	sql text;
	ret text;

BEGIN
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




-- _HT_CreateDiffType(text, text)
CREATE OR REPLACE FUNCTION _HT_CreateDiffType(dbschema text, dbtable text)
RETURNS boolean AS
$$
DECLARE
	sql_get_fields text;
	rec RECORD;
	
	fields text;
	sql_create_type text;

BEGIN

	sql_get_fields := 'SELECT column_name, udt_name FROM information_schema.columns
		WHERE table_schema = ''' || quote_ident(dbschema) || ''' 
		AND table_name = ''' || quote_ident(dbtable) || '''
		ORDER BY ordinal_position';

	fields := 'operation character(1)';
	FOR rec IN EXECUTE(sql_get_fields) LOOP
		fields := fields || ', ' || rec.column_name || ' ' || rec.udt_name;
	END LOOP;

	sql_create_type := 
		'CREATE TYPE ' || quote_ident(dbschema) || '.' || 'ht_' || quote_ident(dbtable) || '_difftype AS (' ||
		fields || ')';
	EXECUTE sql_create_type;

	RETURN True;
END;
$$
LANGUAGE plpgsql VOLATILE;




-- HT_Init(text, text)
CREATE OR REPLACE FUNCTION HT_Init(dbschema text, dbtable text)
	RETURNS text AS
$BODY$

dbschema = args[0]
dbtable = args[1]
dbuser = plpy.execute("SELECT current_user AS current_user")[0]['current_user']
table_fields = plpy.execute("SELECT _HT_GetTableFields('%s', '%s') AS table_fields" % (dbschema, dbtable))[0]['table_fields']
pkey = plpy.execute("SELECT _HT_GetTablePkey('%s', '%s') AS pkey" % (dbschema, dbtable))[0]['pkey']
current_timestamp = plpy.execute("SELECT current_timestamp(0) AS current_timestamp")[0]['current_timestamp']

vars = {'dbschema': dbschema, 'dbtable': dbtable, 'dbuser': dbuser, 'table_fields': table_fields, 'pkey': pkey, 'current_timestamp': current_timestamp}

# test if table exists
if plpy.execute("SELECT _HT_TableExists('%(dbschema)s', '%(dbtable)s') AS tableexists" % vars)[0]['tableexists'] is False:
	plpy.error('Table does not exist.')

# test if table is containing primary key
if vars['pkey'] is None:
	plpy.error('Table is missing primary key.')

#HISTORY TAB
sql_history_tab = """
	CREATE TABLE history_tracker.%(dbschema)s__%(dbtable)s AS SELECT * FROM %(dbschema)s.%(dbtable)s;

	ALTER TABLE history_tracker.%(dbschema)s__%(dbtable)s ADD time_start timestamp, ADD time_end timestamp, 
		ADD dbuser character varying, ADD id_history serial;
	ALTER TABLE history_tracker.%(dbschema)s__%(dbtable)s ADD PRIMARY KEY (id_history);
	
	CREATE INDEX idx_%(dbschema)s__%(dbtable)s_id_history
		ON history_tracker.%(dbschema)s__%(dbtable)s
		USING btree (id_history);
	CREATE INDEX idx_%(dbschema)s__%(dbtable)s_%(pkey)s
		ON history_tracker.%(dbschema)s__%(dbtable)s
		USING btree (%(pkey)s);
	
	COMMENT ON TABLE history_tracker.%(dbschema)s__%(dbtable)s IS 
		'Origin: %(dbschema)s.%(dbtable)s, Created: %(current_timestamp)s, Creator: %(dbuser)s.';
""" % vars


sql_history_tab2 = """
	UPDATE history_tracker.%(dbschema)s__%(dbtable)s SET time_start = now();
	
	INSERT INTO history_tracker.tags (id_tag, dbschema, dbtable, dbuser, time_tag, message, changes_count)
		VALUES (1, '%(dbschema)s', '%(dbtable)s', '%(dbuser)s', current_timestamp, 'History init.', 0);
""" % vars

sql_create_difftype = "SELECT _HT_CreateDiffType('%(dbschema)s', '%(dbtable)s');" % vars

if plpy.execute("SELECT _HT_TableExists('history_tracker', '%(dbschema)s__%(dbtable)s') AS tableexists" % vars)[0]['tableexists'] is False:
	plpy.execute(sql_history_tab)
	plpy.execute(sql_history_tab2)
	plpy.execute(sql_create_difftype)
else:
	plpy.warning('History already enabled, upgrading history triggers.')

#AtTime function 
sql_attime_funct = """
	CREATE OR REPLACE FUNCTION %(dbschema)s.%(dbtable)s_AtTime(timestamp)
	RETURNS SETOF %(dbschema)s.%(dbtable)s AS
	$$
	SELECT %(table_fields)s FROM history_tracker.%(dbschema)s__%(dbtable)s WHERE
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
		IF difftime >= (SELECT MIN(time_tag) FROM history_tracker.tags WHERE dbschema = '%(dbschema)s' AND dbtable = '%(dbtable)s') THEN
			RETURN QUERY
				SELECT ':'::character(1) AS operation, * FROM %(dbschema)s.%(dbtable)s 
				WHERE %(pkey)s IN
					(SELECT DISTINCT %(pkey)s FROM history_tracker.%(dbschema)s__%(dbtable)s   
						WHERE time_start > difftime AND time_end IS NULL)
				AND %(pkey)s IN
					(SELECT DISTINCT ON (%(pkey)s) %(pkey)s FROM history_tracker.%(dbschema)s__%(dbtable)s   
						WHERE time_start <= difftime ORDER BY %(pkey)s, time_start DESC)

				UNION ALL
				
				SELECT '+'::character(1) AS operation, * FROM %(dbschema)s.%(dbtable)s 
				WHERE %(pkey)s IN
					(SELECT DISTINCT %(pkey)s FROM history_tracker.%(dbschema)s__%(dbtable)s   
						WHERE time_start > difftime AND time_end IS NULL)
				AND %(pkey)s NOT IN
					(SELECT DISTINCT ON (%(pkey)s) %(pkey)s FROM history_tracker.%(dbschema)s__%(dbtable)s   
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

#Diff(timestamp, timestamp) function
sql_diffbetweentimes_funct = """
	CREATE OR REPLACE FUNCTION %(dbschema)s.%(dbtable)s_Diff(starttime timestamp, endtime timestamp)
	RETURNS SETOF %(dbschema)s.ht_%(dbtable)s_difftype AS
	$$
	BEGIN
		IF starttime >= (SELECT MIN(time_tag) FROM history_tracker.tags WHERE dbschema = '%(dbschema)s' AND dbtable = '%(dbtable)s') AND endtime <= (SELECT now()) THEN
			RETURN QUERY
				SELECT ':'::character(1) AS operation, * FROM %(dbschema)s.%(dbtable)s_AtTime(endtime)
				WHERE %(pkey)s IN
					(SELECT DISTINCT %(pkey)s FROM history_tracker.%(dbschema)s__%(dbtable)s
						WHERE time_start >= starttime AND time_start < endtime)
				AND %(pkey)s IN
					(SELECT DISTINCT %(pkey)s FROM %(dbschema)s.%(dbtable)s_AtTime(starttime))

				UNION ALL

				SELECT '+'::character(1) AS operation, * FROM %(dbschema)s.%(dbtable)s_AtTime(endtime)
				WHERE %(pkey)s NOT IN
					(SELECT DISTINCT %(pkey)s FROM %(dbschema)s.%(dbtable)s_AtTime(starttime))

				UNION ALL

				SELECT '-'::character(1) AS operation, * FROM %(dbschema)s.%(dbtable)s_AtTime(starttime)
				WHERE %(pkey)s NOT IN
					(SELECT DISTINCT %(pkey)s FROM %(dbschema)s.%(dbtable)s_AtTime(endtime));

		ELSE
			RAISE WARNING 'Can not make diff because start or end time is outside history period.';
			RETURN;
		END IF;
	END;
	$$
	LANGUAGE 'plpgsql';
""" % vars
plpy.execute(sql_diffbetweentimes_funct)

#Diff() function
sql_difftotime_funct = """
	CREATE OR REPLACE FUNCTION %(dbschema)s.%(dbtable)s_Diff()
	RETURNS SETOF %(dbschema)s.ht_%(dbtable)s_difftype AS
	$$
	DECLARE
		difftime timestamp;
		ret_row record;
	BEGIN
		difftime := (SELECT MAX(time_tag) FROM history_tracker.tags WHERE dbschema = '%(dbschema)s' AND dbtable = '%(dbtable)s');
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
		IF difftag <= (SELECT MAX(id_tag) FROM history_tracker.tags WHERE dbschema = '%(dbschema)s' AND dbtable = '%(dbtable)s') THEN
			difftime := (SELECT time_tag FROM history_tracker.tags WHERE dbschema = '%(dbschema)s' AND dbtable = '%(dbtable)s' AND id_tag = difftag);
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
		INSERT INTO history_tracker.%(dbschema)s__%(dbtable)s VALUES (NEW.*);	
	RETURN NEW;
	END;
	$$
	LANGUAGE 'plpgsql';

	DROP TRIGGER IF EXISTS tg_%(dbtable)s_insert ON %(dbschema)s.%(dbtable)s;
	CREATE TRIGGER tg_%(dbtable)s_insert AFTER INSERT ON %(dbschema)s.%(dbtable)s
	FOR EACH ROW EXECUTE PROCEDURE %(dbschema)s.tg_%(dbtable)s_insert();

	
	
	CREATE OR REPLACE FUNCTION history_tracker.tg_%(dbschema)s__%(dbtable)s_insert()
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

	DROP TRIGGER IF EXISTS tg_%(dbschema)s__%(dbtable)s_insert ON history_tracker.%(dbschema)s__%(dbtable)s;
	CREATE TRIGGER tg_%(dbschema)s__%(dbtable)s_insert BEFORE INSERT ON history_tracker.%(dbschema)s__%(dbtable)s
	FOR EACH ROW EXECUTE PROCEDURE history_tracker.tg_%(dbschema)s__%(dbtable)s_insert();
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
		UPDATE history_tracker.%(dbschema)s__%(dbtable)s SET %(sql_update_str1)s WHERE %(pkey)s = NEW.%(pkey)s;
	RETURN NEW;
	END;
	$$
	LANGUAGE 'plpgsql';

	DROP TRIGGER IF EXISTS tg_%(dbtable)s_update ON %(dbschema)s.%(dbtable)s;
	CREATE TRIGGER tg_%(dbtable)s_update AFTER UPDATE ON %(dbschema)s.%(dbtable)s
	FOR EACH ROW EXECUTE PROCEDURE %(dbschema)s.tg_%(dbtable)s_update();



	CREATE OR REPLACE FUNCTION history_tracker.tg_%(dbschema)s__%(dbtable)s_update()
	RETURNS TRIGGER AS
	$$
	BEGIN
	IF OLD.time_end IS NOT NULL THEN
	RETURN NULL;
	END IF;
	IF NEW.time_end IS NULL THEN
	INSERT INTO history_tracker.%(dbschema)s__%(dbtable)s
		(%(table_fields)s, time_start, time_end, dbuser) VALUES (%(sql_update_str2)s, OLD.time_start, current_timestamp, current_user);
	NEW.time_start = current_timestamp;
	END IF;
	RETURN NEW;
	END;
	$$
	LANGUAGE 'plpgsql';
	
	DROP TRIGGER IF EXISTS tg_%(dbschema)s__%(dbtable)s_update ON history_tracker.%(dbschema)s__%(dbtable)s;
	CREATE TRIGGER tg_%(dbschema)s__%(dbtable)s_update BEFORE UPDATE ON history_tracker.%(dbschema)s__%(dbtable)s
	FOR EACH ROW EXECUTE PROCEDURE history_tracker.tg_%(dbschema)s__%(dbtable)s_update();
""" % sql_update_vars
plpy.execute(sql_update_funct)


#DELETE
sql_delete_funct = """
	CREATE OR REPLACE FUNCTION %(dbschema)s.tg_%(dbtable)s_delete()
	RETURNS TRIGGER AS
	$$
	BEGIN
		DELETE FROM history_tracker.%(dbschema)s__%(dbtable)s WHERE %(pkey)s = OLD.%(pkey)s;
	RETURN OLD;
	END;
	$$
	LANGUAGE 'plpgsql';

	DROP TRIGGER IF EXISTS tg_%(dbtable)s_delete ON %(dbschema)s.%(dbtable)s;
	CREATE TRIGGER tg_%(dbtable)s_delete AFTER DELETE ON %(dbschema)s.%(dbtable)s
	FOR EACH ROW EXECUTE PROCEDURE %(dbschema)s.tg_%(dbtable)s_delete();

	DROP RULE IF EXISTS %(dbschema)s__%(dbtable)s_del ON history_tracker.%(dbschema)s__%(dbtable)s;
	CREATE RULE %(dbschema)s__%(dbtable)s_del AS ON DELETE TO history_tracker.%(dbschema)s__%(dbtable)s
	DO INSTEAD UPDATE history_tracker.%(dbschema)s__%(dbtable)s SET time_end = current_timestamp, dbuser = current_user
		WHERE id_history = OLD.id_history AND time_end IS NULL;
""" % vars
plpy.execute(sql_delete_funct)

return "History is enabled."

$BODY$
LANGUAGE 'plpythonu' VOLATILE;
COMMENT ON FUNCTION HT_Init(text, text) IS
	'HT: Enable history. USAGE: HT_Init(<schema>, <table>)';




-- HT_Drop(text, text)
CREATE OR REPLACE FUNCTION HT_Drop(dbschema text, dbtable text)
RETURNS text AS
$$
DECLARE
	sql_hist_table_exists text;
	hist_table_exists boolean;

BEGIN
	-- test if history is enabled
	sql_hist_table_exists :=
		'SELECT _HT_TableExists(''history_tracker'', ''' || quote_ident(dbschema) || '__' || quote_ident(dbtable) || ''')';
	EXECUTE sql_hist_table_exists INTO hist_table_exists;

	IF hist_table_exists IS False THEN
		RAISE EXCEPTION 'History is not enabled.';
	END IF;

	--INSERT
	EXECUTE	'DROP TRIGGER tg_' || quote_ident(dbschema) || '__' || quote_ident(dbtable) || '_insert 
		ON history_tracker.' || quote_ident(dbschema) || '__' || quote_ident(dbtable);
	EXECUTE 'DROP FUNCTION history_tracker.tg_' || quote_ident(dbschema) || '__' || quote_ident(dbtable) || '_insert()';

	EXECUTE 'DROP TRIGGER tg_' || quote_ident(dbtable) || '_insert ON ' || quote_ident(dbschema) || '.' || quote_ident(dbtable);
	EXECUTE 'DROP FUNCTION ' || quote_ident(dbschema) || '.tg_' || quote_ident(dbtable) || '_insert()';

	--UPDATE
	EXECUTE 'DROP TRIGGER tg_' || quote_ident(dbschema) || '__' || quote_ident(dbtable) || '_update 
		ON history_tracker.' || quote_ident(dbschema) || '__' || quote_ident(dbtable);
	EXECUTE 'DROP FUNCTION history_tracker.tg_' || quote_ident(dbschema) || '__' || quote_ident(dbtable) || '_update()';

	EXECUTE 'DROP TRIGGER tg_' || quote_ident(dbtable) || '_update ON ' || quote_ident(dbschema) || '.' || quote_ident(dbtable);
	EXECUTE 'DROP FUNCTION ' || quote_ident(dbschema) || '.tg_' || quote_ident(dbtable) || '_update()';

	--DELETE
	EXECUTE 'DROP RULE ' || quote_ident(dbschema) || '__' || quote_ident(dbtable) || '_del 
		ON history_tracker.' || quote_ident(dbschema) || '__' || quote_ident(dbtable);
		
	EXECUTE 'DROP TRIGGER tg_' || quote_ident(dbtable) || '_delete ON ' || quote_ident(dbschema) || '.' || quote_ident(dbtable);
	EXECUTE 'DROP FUNCTION ' || quote_ident(dbschema) || '.tg_' || quote_ident(dbtable) || '_delete()';

	--FUNCTIONS
	EXECUTE 'DROP FUNCTION ' || quote_ident(dbschema) || '.' || quote_ident(dbtable) || '_Diff()';
	EXECUTE 'DROP FUNCTION ' || quote_ident(dbschema) || '.' || quote_ident(dbtable) || '_AtTime(timestamp)';
	EXECUTE 'DROP FUNCTION ' || quote_ident(dbschema) || '.' || quote_ident(dbtable) || '_Diff(timestamp)';
	EXECUTE 'DROP FUNCTION ' || quote_ident(dbschema) || '.' || quote_ident(dbtable) || '_DiffToTag(integer)';

	--TYPES
	EXECUTE 'DROP TYPE ' || quote_ident(dbschema) || '.ht_' || quote_ident(dbtable) || '_difftype';

	--TAGS
	EXECUTE 'DELETE FROM history_tracker.tags WHERE dbschema = ''' || quote_ident(dbschema) || ''' 
		AND dbtable = ''' || quote_ident(dbtable) || '''';

	--HISTORY TABLE
	EXECUTE 'DROP TABLE history_tracker.' || quote_ident(dbschema) || '__' || quote_ident(dbtable);

	RETURN 'History is disabled.';
END;
$$
LANGUAGE plpgsql VOLATILE;
COMMENT ON FUNCTION HT_Drop(text, text) IS
	'HT: Disable history. USAGE: HT_Drop(<schema>, <table>)';




-- HT_Tag(text, text, text)
CREATE OR REPLACE FUNCTION HT_Tag(dbschema text, dbtable text, message text)
RETURNS text AS
$$
DECLARE
	sql_hist_table_exists text;
	hist_table_exists boolean;

	sql_pkey text;
	pkey text;

	sql_last_tag_time text;
	last_tag_time timestamp;

	sql_changes_count text;
	changes_count integer;

	sql_insert_tag text;

BEGIN
	-- test if history is enabled
	sql_hist_table_exists := 
		'SELECT _HT_TableExists(''history_tracker'', ''' || quote_ident(dbschema) || '__' || quote_ident(dbtable) || ''')';
	EXECUTE sql_hist_table_exists INTO hist_table_exists;

	IF hist_table_exists IS False THEN
		RAISE EXCEPTION 'History is not enabled or table does not exists.';
	END IF;

	-- table properties
	sql_pkey := 'SELECT _HT_GetTablePkey(''' || quote_ident(dbschema) || ''', ''' || quote_ident(dbtable) || ''')';
	EXECUTE sql_pkey INTO pkey;

	sql_last_tag_time := 'SELECT MAX(time_tag) FROM  history_tracker.tags WHERE 
		dbschema = ''' || quote_ident(dbschema) || ''' AND dbtable = ''' || quote_ident(dbtable) || '''';
	EXECUTE sql_last_tag_time INTO last_tag_time;

	sql_changes_count := 'SELECT COUNT(*) FROM '
		|| quote_ident(dbschema) || '.' || quote_ident(dbtable) || '_diff(''' || last_tag_time || ''')';
	EXECUTE sql_changes_count INTO changes_count;

	-- insert tag
	IF changes_count > 0 THEN
		sql_insert_tag := 'INSERT INTO history_tracker.tags 
			(id_tag, dbschema, dbtable, dbuser, time_tag, changes_count, message)
			VALUES (_HT_NextTagValue(''' || quote_ident(dbschema) || ''', ''' || quote_ident(dbtable) || '''), '''
				|| quote_ident(dbschema) || ''', ''' || quote_ident(dbtable) || ''', current_user, 
				current_timestamp, ' || changes_count || ', ''' || message || ''')';
		EXECUTE sql_insert_tag;
		RETURN 'Tag recorded.';
	ELSE
		RAISE WARNING 'Nothing has changed since last tag.';
		RETURN 'No tag written.';
	END IF;
END;
$$
LANGUAGE plpgsql VOLATILE;
COMMENT ON FUNCTION HT_Tag(text, text, text) IS
	'HT: Add tag. USAGE: HT_Tag(<schema>, <table>, <message>)';



--HT_Log(text, text)
CREATE OR REPLACE FUNCTION HT_Log(text, text)
	RETURNS SETOF history_tracker.tags AS
$$
	SELECT * FROM history_tracker.tags WHERE dbschema = $1 AND dbtable = $2 ORDER BY id DESC;
$$
LANGUAGE 'SQL';
COMMENT ON FUNCTION HT_Log(text, text) IS
	'HT: Get log for given table. USAGE: HT_Log(<schema>, <table>)';

--HT_Log()
CREATE OR REPLACE FUNCTION HT_Log()
	RETURNS SETOF history_tracker.tags AS
$$
	SELECT * FROM history_tracker.tags ORDER BY id DESC;
$$
LANGUAGE 'SQL';
COMMENT ON FUNCTION HT_Log() IS
	'HT: Get log. USAGE: HT_Log()';




-- # vim: set syntax=sql ts=4 sts=4 sw=4 noet:
