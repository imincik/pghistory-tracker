SET client_min_messages = warning;

CREATE TABLE myschema.mytable
(
	id serial PRIMARY KEY,
	aaa integer,
	bbb character varying
);
CREATE INDEX idx_mytable_id
	ON myschema.mytable
	USING btree
	(id);

