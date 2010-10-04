--DROP FUNCTION gis.G_CreateGISHistory(text, text);
CREATE OR REPLACE FUNCTION gis.G_CreateGISHistory(dbschema text, dbtable text)
	RETURNS integer AS
$BODY$

dbschema = args[0]
dbtable = args[1]
vars = {'dbschema': dbschema, 'dbtable': dbtable} 

sql_history_tab = """
	CREATE TABLE gis_history.hist_%(dbschema)s_%(dbtable)s AS SELECT * FROM %(dbschema)s.%(dbtable)s;

	ALTER TABLE gis_history.hist_%(dbschema)s_%(dbtable)s ADD time_start timestamp, ADD time_end timestamp, ADD id_hist serial;
	ALTER TABLE gis_history.hist_%(dbschema)s_%(dbtable)s ADD PRIMARY KEY (id_hist);

	CREATE INDEX idx_hist_%(dbschema)s_%(dbtable)s_id_hist
		ON gis_history.hist_%(dbschema)s_%(dbtable)s
		USING btree (id_hist);
	CREATE INDEX idx_hist_%(dbschema)s_%(dbtable)s_gid
		ON gis_history.hist_%(dbschema)s_%(dbtable)s
		USING btree (gid);
	CREATE INDEX spx_hist_%(dbschema)s_%(dbtable)s
		ON gis_history.hist_%(dbschema)s_%(dbtable)s
		USING gist (the_geom);

	COMMENT ON TABLE gis_history.hist_%(dbschema)s_%(dbtable)s IS 'GIS history table.';
""" % vars
plpy.execute(sql_history_tab)

sql_insert_funct = """
	CREATE OR REPLACE FUNCTION %(dbschema)s.tg_%(dbtable)s_insert()
	RETURNS TRIGGER AS
	$$
	BEGIN
		INSERT INTO gis_history.hist_%(dbschema)s_%(dbtable)s VALUES (NEW.*, now());	
	RETURN NEW;
	END;
	$$
	LANGUAGE 'plpgsql';

	CREATE TRIGGER tg_%(dbtable)s_insert BEFORE INSERT ON %(dbschema)s.%(dbtable)s
	FOR EACH ROW EXECUTE PROCEDURE %(dbschema)s.tg_%(dbtable)s_insert();
""" % vars
plpy.execute(sql_insert_funct)

sql_update_funct = """
	CREATE OR REPLACE FUNCTION %(dbschema)s.tg_%(dbtable)s_update()
	RETURNS TRIGGER AS
	$$
	BEGIN
		INSERT INTO gis_history.hist_%(dbschema)s_%(dbtable)s VALUES (OLD.*, now(), now());
	RETURN NEW;
	END;
	$$
	LANGUAGE 'plpgsql';

	CREATE TRIGGER tg_%(dbtable)s_update BEFORE UPDATE ON %(dbschema)s.%(dbtable)s
	FOR EACH ROW EXECUTE PROCEDURE %(dbschema)s.tg_%(dbtable)s_update();
""" % vars
plpy.execute(sql_update_funct)


return 1

$BODY$
LANGUAGE 'plpythonu' VOLATILE
