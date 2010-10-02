--
-- 						=== LAYERS ===								--
--



-- !! FAKE FUNCTION
-- GT_Gisplan_User
CREATE OR REPLACE FUNCTION GT_Gisplan_User() 
	RETURNS text AS 
$$
	SELECT 'ivo'::text;
$$ LANGUAGE SQL;
ALTER FUNCTION gt_gisplan_user() OWNER TO mapadmin;
COMMENT ON FUNCTION GT_Gisplan_User() IS 'Gisplan: Get Gisplan application user. USAGE: GT_Gisplan_User()';


-- GT_Register_Layer
CREATE OR REPLACE FUNCTION GT_Register_Layer(layer text)
	RETURNS integer AS
$BODY$

from datetime import datetime

layer = args[0]
dtime = str(datetime.now())
g_user = plpy.execute('SELECT GT_Gisplan_User()')[0]['gt_gisplan_user']
vars = {'layer': layer, 'g_user': g_user, 'dtime': dtime}


sql_create_history_layer = """
	CREATE TABLE gis_history.hist_gis_%(layer)s AS SELECT * FROM gis.v_%(layer)s;

	ALTER TABLE gis_history.hist_gis_%(layer)s ADD time_start timestamp, ADD time_end timestamp, ADD id_hist serial;
	ALTER TABLE gis_history.hist_gis_%(layer)s ADD PRIMARY KEY (id_hist);

	ALTER TABLE gis_history.hist_gis_%(layer)s OWNER TO %(g_user)s;
	ALTER TABLE gis_history.hist_gis_%(layer)s OWNER TO %(g_user)s;
	
	CREATE INDEX idx_hist_gis_%(layer)s_id_hist
		ON gis_history.hist_gis_%(layer)s
		USING btree (id_hist);
	CREATE INDEX idx_hist_gis_%(layer)s_gid
		ON gis_history.hist_gis_%(layer)s
		USING btree (gid);
	CREATE INDEX spx_hist_gis_%(layer)s
		ON gis_history.hist_gis_%(layer)s
		USING gist (the_geom);

	COMMENT ON TABLE gis_history.hist_gis_%(layer)s IS 'Gisplan HISTORY layer';

""" % vars
plpy.execute(sql_create_history_layer)

sql_create_rlayer = """
	CREATE TABLE gis.r_%(layer)s AS SELECT * FROM gis.v_%(layer)s;

	INSERT INTO geometry_columns (f_table_catalog, f_table_schema, f_table_name, f_geometry_column, coord_dimension, srid, type)
            	VALUES ('', (SELECT f_table_schema FROM geometry_columns WHERE f_table_name = 'v_%(layer)s'), 'r_%(layer)s', 'the_geom', 2, 
			(SELECT srid FROM geometry_columns WHERE f_table_name = 'v_%(layer)s'), 
			(SELECT type FROM geometry_columns WHERE f_table_name = 'v_%(layer)s'));
	
	ALTER TABLE gis.r_%(layer)s ADD PRIMARY KEY (gid);
		
	ALTER TABLE gis.r_%(layer)s OWNER TO %(g_user)s;
	ALTER TABLE gis.v_%(layer)s OWNER TO %(g_user)s;
	
	CREATE INDEX idx_r_%(layer)s_gid
		ON gis.r_%(layer)s
		USING btree (gid);
	CREATE INDEX spx_r_%(layer)s
		ON gis.r_%(layer)s
		USING gist (the_geom);

	COMMENT ON TABLE gis.v_%(layer)s IS 'Registred Gisplan -v- layer at %(dtime)s';
	COMMENT ON TABLE gis.r_%(layer)s IS 'Registred Gisplan rendering -r- layer at %(dtime)s';

	--INSERT INTO postgis_log (\"operation\", \"time\", \"user\", \"dbschema\", \"dbtable\", \"is_updated\", \"the_geom\") 
	--	VALUES ('R', now(), 'gisplan_registrator', 'gis', 'v_%(layer)s', 'true', NULL);
	--INSERT INTO gisplan_management_registered_tables (\"dbschema\", \"dbtable\", \"registered_time\") VALUES ('gis', '%(layer)s', now());

""" % vars
plpy.execute(sql_create_rlayer)


sql_create_insert_f = """
	CREATE OR REPLACE FUNCTION gis.tg_v_%(layer)s_insert()
	RETURNS TRIGGER AS
	$$
	BEGIN
		INSERT INTO gis_history.hist_gis_%(layer)s VALUES (NEW.*, now());	
	RETURN NEW;
	END;
	$$
	LANGUAGE 'plpgsql';

	CREATE TRIGGER tg_v_%(layer)s_insert BEFORE INSERT ON gis.v_%(layer)s
	FOR EACH ROW EXECUTE PROCEDURE tg_v_%(layer)s_insert();
""" % vars
plpy.execute(sql_create_insert_f)


sql_grant = """	
	GRANT SELECT, UPDATE, INSERT, DELETE ON gis.v_%(layer)s TO mapeditors;
	GRANT SELECT ON gis.v_%(layer)s TO mapreaders;
	GRANT UPDATE ON gis.v_%(layer)s_gid_seq TO mapeditors;
""" % vars
plpy.execute(sql_grant)

sql_postgis_log = """ 
	--CREATE TRIGGER tg_v_%(layer)s_postgis_log AFTER INSERT OR UPDATE OR DELETE ON gis.v_%(layer)s FOR EACH ROW EXECUTE PROCEDURE postgis_log();
""" % vars
plpy.execute(sql_postgis_log)

plpy.info("Gisplan layer %(layer)s is registred. " % vars)

return 1
$BODY$
	LANGUAGE 'plpythonu' VOLATILE
	COST 100;
ALTER FUNCTION GT_Register_Layer(text) OWNER TO mapadmin;
COMMENT ON FUNCTION GT_Register_Layer(text) IS 'Gisplan: Register Gisplan GIS layer. USAGE: GT_Register_Layer(<layer_name_without_prefix>)';


-- GT_UnRegister_Layer
CREATE OR REPLACE FUNCTION GT_UnRegister_Layer(layer text)
	RETURNS integer AS
$BODY$

from datetime import datetime

layer = args[0]
dtime = str(datetime.now())
vars = {'layer': layer, 'dtime': dtime}

sql = """
	SELECT DropGeometryTable('gis', 'r_%(layer)s');
	DROP TRIGGER tg_v_%(layer)s_postgis_log ON gis.v_%(layer)s;
	UPDATE postgis_log SET \"is_updated\" = false WHERE \"dbschema\" = 'gis' AND \"dbtable\" = 'v_%(layer)s';
	DELETE FROM gisplan_management_registered_tables WHERE \"dbschema\" = 'gis' AND \"dbtable\" = '%(layer)s';
	COMMENT ON TABLE v_%(layer)s IS 'Unregistred Gisplan -v- layer at %(dtime)s';
""" % vars
plpy.execute(sql)

plpy.info("Gisplan layer %s is unregistred. " % (layer))

return 1
$BODY$
	LANGUAGE 'plpythonu' VOLATILE
	COST 100;
ALTER FUNCTION GT_UnRegister_Layer(text) OWNER TO mapadmin;
COMMENT ON FUNCTION GT_UnRegister_Layer(text) IS 'Gisplan: UnRegister Gisplan GIS layer. USAGE: GT_UnRegister_Layer(<layer_name_without_prefix>)';


-- GT_Update_Layer
CREATE OR REPLACE FUNCTION GT_Update_Layer(layer text)
	RETURNS integer AS
$BODY$

layer = args[0]
vars = {'layer': layer}

sql = """
         DELETE FROM gis.r_%(layer)s;
         INSERT INTO gis.r_%(layer)s SELECT * FROM gis.v_%(layer)s;
	 UPDATE postgis_log SET \"is_updated\" = false WHERE \"dbschema\" = 'gis' AND \"dbtable\" = 'v_%(layer)s';
""" % vars
plpy.info("Updating layer r_%(layer)s from v_%(layer)s ..." % vars)
plpy.execute(sql)

return 1
$BODY$
	LANGUAGE 'plpythonu' VOLATILE
	COST 100;
ALTER FUNCTION GT_Update_Layer(text) OWNER TO mapadmin;
COMMENT ON FUNCTION GT_Update_Layer(text) IS 'Gisplan: Update Gisplan GIS -r- layer using -v- layer. USAGE: GT_Update_Layer(<layer_name_without_prefix>)';



-- GT_TwoTypes_Layer
CREATE OR REPLACE FUNCTION GT_TwoTypes_Layer(layer text)
	RETURNS integer AS
$BODY$

layer = args[0]
lay_type = plpy.execute("SELECT type FROM geometry_columns WHERE f_table_schema = 'gis' AND f_table_name = 'v_%s'" % layer)[0]['type']
lay_type = lay_type.replace('MULTI', '')
vars = {'layer': layer, 'lay_type': lay_type}

sql_constr = """
	ALTER TABLE gis.v_%(layer)s DROP CONSTRAINT enforce_geotype_the_geom;
	ALTER TABLE gis.v_%(layer)s ADD CONSTRAINT enforce_geotype_the_geom CHECK (geometrytype(the_geom) = '%(lay_type)s'::text OR
		geometrytype(the_geom) = 'MULTI%(lay_type)s'::text OR the_geom IS NULL);

""" % vars
plpy.execute(sql_constr)

plpy.info("Changed constraint to support %s and MULTI%s geometry types." % (lay_type, lay_type))

return 1
$BODY$
	LANGUAGE 'plpythonu' VOLATILE
	COST 100;
ALTER FUNCTION GT_TwoTypes_Layer(text) OWNER TO mapadmin;
COMMENT ON FUNCTION GT_TwoTypes_Layer(text) IS 'Gisplan: Alter Gisplan -v- layer with constraint supporting SINGLE and MULTI-geometry types. USAGE: GT_TwoTypes_Layer(<layer_name_without_prefix>)';



