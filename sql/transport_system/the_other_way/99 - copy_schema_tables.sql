-- Select fn_copy_schema_tables('public', 'staging', 'tbl_sites', FALSE)
-- ScheiSe: FK constraints not copied
CREATE OR REPLACE FUNCTION fn_copy_schema_tables(p_source_schema text, p_target_schema text, p_table_name text=NULL, p_dry_run BOOLEAN=TRUE) RETURNS void AS
$$
 DECLARE
  v_table_name text;
  v_column_name text;
  v_sequence_name text;
  v_sql text;
  x RECORD;
BEGIN
	v_sql = format(E'\nCREATE SCHEMA IF NOT EXISTS %I;\n', p_target_schema);
	FOR v_table_name IN
		SELECT table_name::text
		FROM information_schema.tables
		WHERE table_catalog = current_database()
		  AND table_type = 'BASE TABLE'
		  AND table_schema = p_source_schema
		  AND coalesce(p_table_name, table_name) = table_name
	LOOP
		v_sql = v_sql || format(E'\nDROP TABLE IF EXISTS %I.%I;', p_target_schema, v_table_name);
		v_sql = v_sql || format(E'\nCREATE TABLE %I.%I (LIKE %I.%I INCLUDING CONSTRAINTS INCLUDING INDEXES INCLUDING DEFAULTS);', p_target_schema, v_table_name, p_source_schema, v_table_name);
		FOR v_column_name, v_sequence_name IN
			WITH columns AS (
				SELECT column_name, replace(pg_get_serial_sequence(v_table_name, column_name), p_source_schema || '.', '') As sequence_name
				FROM information_schema.columns
				WHERE table_catalog = current_database()
				  AND NOT column_default IS NULL
				  AND table_schema = p_source_schema
				  AND table_name = v_table_name
				  AND data_type in ('integer', 'bigint', 'smallint')
			)
			SELECT column_name, sequence_name
			FROM columns
			WHERE NOT sequence_name IS NULL
		LOOP
			v_sql = v_sql || format(E'\nDROP SEQUENCE IF EXISTS %I.%I;', p_target_schema, v_sequence_name);
			v_sql = v_sql || format(E'\nCREATE SEQUENCE %I.%I;', p_target_schema, v_sequence_name);
			v_sql = v_sql || format(E'\nALTER TABLE %I.%I ALTER COLUMN %I SET DEFAULT nextval(''%I.%I'');\n', p_target_schema, v_table_name, v_column_name, p_target_schema, v_sequence_name);
		END LOOP;	
	END LOOP;
	
	v_sql = v_sql || format(E'\nSET search_path TO %I, public', p_target_schema);
	for x in
        select c.conrelid::regclass as table_name, c.oid, c.conname
        from pg_constraint c
		join information_schema.tables t
		  on t.table_schema = 'proof_of_concept' -- p_target_schema
		 and t.table_name::text = c.conrelid::regclass::text
        where c.contype = 'f' 
    loop
        v_sql = v_sql || format(E'\nALTER TABLE %I.%I ADD CONSTRAINT %I.%I %s',
            p_target_schema, x.table_name,
			p_target_schema, x.conname,			
            REPLACE(pg_get_constraintdef(x.oid), 'REFERENCES ', 'REFERENCES ' || p_target_schema || '.'));
    end loop;
	
	IF p_dry_run THEN
		RAISE NOTICE '%', v_sql;
	ELSE
		EXECUTE v_sql;
	END IF;
END;

$$ LANGUAGE plpgsql VOLATILE;
