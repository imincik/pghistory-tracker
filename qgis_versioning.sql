BEGIN;

ALTER TABLE gis.v_ulice ADD id_hist serial, ADD time_start timestamp, ADD time_end timestamp;

ALTER TABLE gis.v_ulice DROP CONSTRAINT v_ulice_pkey, ADD PRIMARY KEY (id_hist);

CREATE VIEW gis.v_ulice_current AS SELECT gid,typ,id_cis_nazvy_ulic,label,the_geom FROM gis.v_ulice WHERE time_end IS NULL;


CREATE OR REPLACE FUNCTION gis.v_ulice_at_time(timestamp)
RETURNS SETOF gis.v_ulice_current AS
$$
SELECT gid,typ,id_cis_nazvy_ulic,label,the_geom FROM gis.v_ulice WHERE
  ( SELECT CASE WHEN time_end IS NULL THEN (time_start <= $1) ELSE (time_start <= $1 AND time_end > $1) END );
$$
LANGUAGE 'SQL';

CREATE OR REPLACE FUNCTION gis.v_ulice_update()
RETURNS TRIGGER AS
$$
BEGIN
  IF OLD.time_end IS NOT NULL THEN
    RETURN NULL;
  END IF;
  IF NEW.time_end IS NULL THEN
    INSERT INTO gis.v_ulice (gid,typ,id_cis_nazvy_ulic,label,the_geom, time_start, time_end) VALUES (OLD.gid,OLD.typ,OLD.id_cis_nazvy_ulic,OLD.label,OLD.the_geom, OLD.time_start, current_timestamp);
    NEW.time_start = current_timestamp;
  END IF;
  RETURN NEW;
END;
$$
LANGUAGE 'plpgsql';

CREATE OR REPLACE FUNCTION gis.v_ulice_insert()
RETURNS trigger AS
$$
BEGIN
  if NEW.time_start IS NULL then
    NEW.time_start = now();
    NEW.time_end = null;
  end if;
  RETURN NEW;
END;
$$
LANGUAGE 'plpgsql';


CREATE RULE v_ulice_del AS ON DELETE TO gis.v_ulice
DO INSTEAD UPDATE gis.v_ulice SET time_end = current_timestamp WHERE id_hist = OLD.id_hist AND time_end IS NULL;

CREATE TRIGGER v_ulice_update BEFORE UPDATE ON gis.v_ulice
FOR EACH ROW EXECUTE PROCEDURE gis.v_ulice_update();

CREATE TRIGGER v_ulice_insert BEFORE INSERT ON gis.v_ulice
FOR EACH ROW EXECUTE PROCEDURE gis.v_ulice_insert();


CREATE OR REPLACE RULE "_DELETE" AS ON DELETE TO gis.v_ulice_current DO INSTEAD
  DELETE FROM gis.v_ulice WHERE gid = old.gid;
CREATE OR REPLACE RULE "_INSERT" AS ON INSERT TO gis.v_ulice_current DO INSTEAD
  INSERT INTO gis.v_ulice (gid,typ,id_cis_nazvy_ulic,label,the_geom) VALUES (NEW.gid,NEW.typ,NEW.id_cis_nazvy_ulic,NEW.label,NEW.the_geom);
CREATE OR REPLACE RULE "_UPDATE" AS ON UPDATE TO gis.v_ulice_current DO INSTEAD
  UPDATE gis.v_ulice SET gid = NEW.gid,typ = NEW.typ,id_cis_nazvy_ulic = NEW.id_cis_nazvy_ulic,label = NEW.label,the_geom = NEW.the_geom WHERE gid = new.gid;


END;
