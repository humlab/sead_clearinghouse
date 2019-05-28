

DO $$
DECLARE
    sead_table record;
    view_template text;
    pk_field_template text;
    fk_field_template text;
    join_clause_template text;    
BEGIN
    pk_field_template = 'CASE WHEN E.public_db_id <= 0 THEN NULL ELSE E.public_db_id END As %I' ;
    fk_field_template = 'CASE WHEN fk%s.public_db_id <= 0 THEN NULL ELSE fk%s.public_db_id END AS %s';
    -- TODO: Use clearing_house table view. Join the same way as in CH reports.
    join_clause_template = 'JOIN clearing_house.%I fk%s ON E.%I = fk%s.local_db_id';
    view_template = '
DROP VIEW IF EXISTS clearing_house_commit.view_%I_resolved;
CREATE OR REPLACE VIEW clearing_house_commit.view_%I_resolved AS
  /*
  ** AUTO-GENERATED VIEW! DO NOT CHANGE THIS VIEW!
  ** This view MUST return the same fields, and in the same order, as public.%I
  ** followed by CH-specific columns.
  **
  ** Please re-create view whenever base table changes!
  **
  ** This view resolves FK key constraints under the assumption that all new
  ** records have been assigned a SEAD ID.
  **/
  SELECT
    %s,
    E.submission_id,
    E.source_id,
    E.local_db_id,
    E.merged_db_id,
    E.public_db_id
  FROM clearing_house.%I AS E
  %s
';
    FOR sead_table IN
        WITH view_componens AS (
            SELECT  T.table_name, T.entity_name, ordinal_position,
                    CASE WHEN is_pk = 'YES'  THEN
                        format(pk_field_template, column_name)
                    WHEN is_fk = 'YES' THEN
                        format(fk_field_template, ordinal_position, ordinal_position, column_name)
                    ELSE
                        'E.' || column_name
                    END AS field_clause,

                    CASE WHEN is_fk = 'YES' THEN
                        format(join_clause_template, fk_table_name, ordinal_position, column_name, ordinal_position)
                    ELSE
                        NULL
                    END AS join_clause
            FROM clearing_house.fn_dba_get_sead_public_db_schema() S
            JOIN clearing_house.tbl_clearinghouse_entity_tables T 
              ON T.table_name = S.table_name
        ) SELECT format(view_template, entity_name, entity_name, table_name,
                        string_agg(field_clause, E',\n    ' ORDER BY ordinal_position), table_name,
                        string_agg(join_clause, E'\n  '  ORDER BY ordinal_position)) AS create_clause
          FROM view_componens
          GROUP BY table_name, entity_name
    LOOP
        RAISE INFO '%', sead_table.create_clause;
        --Execute sead_table.create_clause;
    END LOOP;
END; $$ language plpgsql;

