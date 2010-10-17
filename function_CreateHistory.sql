CREATE OR REPLACE FUNCTION SV_CreateHistory(dbschema text, dbtable text)
	RETURNS integer AS
$BODY$

from datetime import datetime

dbschema = args[0]
dbtable = args[1]
dbuser = plpy.execute("SELECT current_user")[0]['current_user']
table_fields = plpy.execute("SELECT SV_GetTableFields('%s', '%s')" % (dbschema, dbtable))[0]['sv_gettablefields']
pkey = plpy.execute("SELECT column_name FROM information_schema.key_column_usage \
	WHERE table_schema = '%s' AND table_name = '%s'" % (dbschema, dbtable))[0]['column_name']
dtime = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

vars = {'dbschema': dbschema, 'dbtable': dbtable, 'dbuser': dbuser, 'table_fields': table_fields, 'pkey': pkey, 'dtime': dtime} 

#HISTORY TAB
sql_history_tab = """
	CREATE TABLE sv_history.%(dbschema)s__%(dbtable)s AS SELECT * FROM %(dbschema)s.%(dbtable)s;

	ALTER TABLE sv_history.%(dbschema)s__%(dbtable)s ADD time_start timestamp, ADD time_end timestamp, 
		ADD dbuser character varying, ADD id_hist serial;
	ALTER TABLE sv_history.%(dbschema)s__%(dbtable)s ADD PRIMARY KEY (id_hist);

	CREATE INDEX idx_%(dbschema)s__%(dbtable)s_id_hist
		ON sv_history.%(dbschema)s__%(dbtable)s
		USING btree (id_hist);
	CREATE INDEX idx_%(dbschema)s__%(dbtable)s_%(pkey)s
		ON sv_history.%(dbschema)s__%(dbtable)s
		USING btree (%(pkey)s);

	COMMENT ON TABLE sv_history.%(dbschema)s__%(dbtable)s IS 'GIS history: %(dbschema)s.%(dbtable)s, Created: %(dtime)s, Creator: %(dbuser)s.';
""" % vars
plpy.execute(sql_history_tab)

#ATTIME FUNCTION 
sql_attime_funct = """
	CREATE OR REPLACE FUNCTION %(dbschema)s.%(dbtable)s_AtTime(timestamp)
	RETURNS SETOF %(dbschema)s.%(dbtable)s AS
	$$
	SELECT %(table_fields)s FROM sv_history.%(dbschema)s__%(dbtable)s WHERE
		( SELECT CASE WHEN time_end IS NULL THEN (time_start <= $1) ELSE (time_start <= $1 AND time_end > $1) END );
	$$
	LANGUAGE 'SQL';
""" % vars
plpy.execute(sql_attime_funct)



#INSERT
sql_insert_funct = """
	CREATE OR REPLACE FUNCTION %(dbschema)s.tg_%(dbtable)s_insert()
	RETURNS TRIGGER AS
	$$
	BEGIN
		INSERT INTO sv_history.%(dbschema)s__%(dbtable)s VALUES (NEW.*);	
	RETURN NEW;
	END;
	$$
	LANGUAGE 'plpgsql';

	CREATE TRIGGER tg_%(dbtable)s_insert BEFORE INSERT ON %(dbschema)s.%(dbtable)s
	FOR EACH ROW EXECUTE PROCEDURE %(dbschema)s.tg_%(dbtable)s_insert();

	
	
	CREATE OR REPLACE FUNCTION sv_history.tg_%(dbschema)s__%(dbtable)s_insert()
	RETURNS trigger AS
	$$
	BEGIN
  	if NEW.time_start IS NULL then
    		NEW.time_start = now();
    		NEW.time_end = null;
		NEW.dbuser = user;
  	end if;
  	RETURN NEW;
	END;
	$$
	LANGUAGE 'plpgsql';

	CREATE TRIGGER tg_%(dbschema)s__%(dbtable)s_insert BEFORE INSERT ON sv_history.%(dbschema)s__%(dbtable)s
	FOR EACH ROW EXECUTE PROCEDURE sv_history.tg_%(dbschema)s__%(dbtable)s_insert();
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
		UPDATE sv_history.%(dbschema)s__%(dbtable)s SET %(sql_update_str1)s WHERE %(pkey)s = NEW.%(pkey)s;
	RETURN NEW;
	END;
	$$
	LANGUAGE 'plpgsql';

	CREATE TRIGGER tg_%(dbtable)s_update BEFORE UPDATE ON %(dbschema)s.%(dbtable)s
	FOR EACH ROW EXECUTE PROCEDURE %(dbschema)s.tg_%(dbtable)s_update();



	CREATE OR REPLACE FUNCTION sv_history.tg_%(dbschema)s__%(dbtable)s_update()
	RETURNS TRIGGER AS
	$$
	BEGIN
	IF OLD.time_end IS NOT NULL THEN
	RETURN NULL;
	END IF;
	IF NEW.time_end IS NULL THEN
	INSERT INTO sv_history.%(dbschema)s__%(dbtable)s
		(%(table_fields)s, time_start, time_end, dbuser) VALUES (%(sql_update_str2)s, OLD.time_start, current_timestamp, user);
	NEW.time_start = current_timestamp;
	END IF;
	RETURN NEW;
	END;
	$$
	LANGUAGE 'plpgsql';
	
	CREATE TRIGGER tg_%(dbschema)s__%(dbtable)s_update BEFORE UPDATE ON sv_history.%(dbschema)s__%(dbtable)s
	FOR EACH ROW EXECUTE PROCEDURE sv_history.tg_%(dbschema)s__%(dbtable)s_update();
""" % sql_update_vars
plpy.execute(sql_update_funct)

#DELETE
sql_delete_funct = """
	CREATE OR REPLACE FUNCTION %(dbschema)s.tg_%(dbtable)s_delete()
	RETURNS TRIGGER AS
	$$
	BEGIN
		DELETE FROM sv_history.%(dbschema)s__%(dbtable)s WHERE %(pkey)s = OLD.%(pkey)s;
	RETURN OLD;
	END;
	$$
	LANGUAGE 'plpgsql';

	CREATE TRIGGER tg_%(dbtable)s_delete BEFORE DELETE ON %(dbschema)s.%(dbtable)s
	FOR EACH ROW EXECUTE PROCEDURE %(dbschema)s.tg_%(dbtable)s_delete();


	CREATE RULE %(dbschema)s__%(dbtable)s_del AS ON DELETE TO sv_history.%(dbschema)s__%(dbtable)s
	DO INSTEAD UPDATE sv_history.%(dbschema)s__%(dbtable)s SET time_end = current_timestamp, dbuser = user
		WHERE id_hist = OLD.id_hist AND time_end IS NULL;

	
""" % vars
plpy.execute(sql_delete_funct)
return 1

$BODY$
LANGUAGE 'plpythonu' VOLATILE
