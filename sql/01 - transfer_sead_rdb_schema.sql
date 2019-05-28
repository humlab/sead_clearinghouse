-- Drop Function If Exists clearing_house.fn_dba_get_sead_public_db_schema(text, text);
/*********************************************************************************************************************************
**  Function    view_foreign_keys
**  When        2019-04-24
**  What        Retrieves foreign keys from all schemas
**  Who         Roger Mähler
**  Uses        information_schema
**  Used By     Clearing House installation. DBA.
**  Note        Assumes all FK-constraints are single key value
**  Revisions
**********************************************************************************************************************************/
create or replace view clearing_house.view_foreign_keys as (
    with table_columns as (
        select t.oid, ns.nspname, t.relname, attr.attname, attr.attnum
        from pg_class t
        join pg_namespace ns
          on ns.oid = t.relnamespace
        join pg_attribute attr
          on attr.attrelid = t.oid
         and attr.attnum > 0
    )
        select distinct
                t.nspname   as schema_name,
                t.oid       as table_oid,
                t.relname   as table_name,
                t.attname   as column_name,
                t.attnum    as attnum,

                s.nspname   as f_schema_name,
                s.relname   as f_table_name,
                s.attname   as f_column_name,
                s.oid       as f_table_oid,
                t.attnum    as f_attnum
        from pg_constraint
        join table_columns t
          on t.oid = pg_constraint.conrelid
         and t.attnum = pg_constraint.conkey[1]
         and (t.attnum = any (pg_constraint.conkey))
        join table_columns s
          on s.oid = pg_constraint.confrelid
         and (s.attnum = any (pg_constraint.confkey))
        where pg_constraint.contype = 'f'::"char"
);

/*********************************************************************************************************************************
**  Function    fn_dba_get_sead_public_db_schema
**  When        2013-10-18
**  What        Retrieves SEAD public db schema catalog
**  Who         Roger Mähler
**  Uses        INFORMATION_SCHEMA.catalog in SEAD production
**  Used By     Clearing House installation. DBA.
**  Revisions   2018-06-23 Major rewrite using pg_xxx tables for faster performance and FK inclusion
**********************************************************************************************************************************/
-- select * from clearing_house.fn_dba_get_sead_public_db_schema3('public')
create or replace function clearing_house.fn_dba_get_sead_public_db_schema(p_schema_name text default 'public', p_owner text default 'sead_master')
    returns table (
        table_schema information_schema.sql_identifier,
        table_name information_schema.sql_identifier,
        column_name information_schema.sql_identifier,
        ordinal_position information_schema.cardinal_number,
        data_type information_schema.character_data,
        numeric_precision information_schema.cardinal_number,
        numeric_scale information_schema.cardinal_number,
        character_maximum_length information_schema.cardinal_number,
        is_nullable information_schema.yes_or_no,
        is_pk information_schema.yes_or_no,
        is_fk information_schema.yes_or_no,
        fk_table_name information_schema.sql_identifier,
        fk_column_name information_schema.sql_identifier
    ) language 'plpgsql'
    as $body$
    begin
        return query
            select
                pg_tables.schemaname::information_schema.sql_identifier as table_schema,
                pg_tables.tablename::information_schema.sql_identifier  as table_name,
                pg_attribute.attname::information_schema.sql_identifier as column_name,
                pg_attribute.attnum::information_schema.cardinal_number as ordinal_position,
                format_type(pg_attribute.atttypid, null)::information_schema.character_data as data_type,
                case pg_attribute.atttypid
                    when 21 /*int2*/ then 16
                    when 23 /*int4*/ then 32
                    when 20 /*int8*/ then 64
                    when 1700 /*numeric*/ then
                        case when pg_attribute.atttypmod = -1
                            then null
                            else ((pg_attribute.atttypmod - 4) >> 16) & 65535     -- calculate the precision
                            end
                    when 700 /*float4*/ then 24 /*flt_mant_dig*/
                    when 701 /*float8*/ then 53 /*dbl_mant_dig*/
                    else null
                end::information_schema.cardinal_number as numeric_precision,
                case
                when pg_attribute.atttypid in (21, 23, 20) then 0
                when pg_attribute.atttypid in (1700) then
                    case
                        when pg_attribute.atttypmod = -1 then null
                        else (pg_attribute.atttypmod - 4) & 65535            -- calculate the scale
                    end
                else null
                end::information_schema.cardinal_number as numeric_scale,
                case when pg_attribute.atttypid not in (1042,1043) or pg_attribute.atttypmod = -1 then null
                    else pg_attribute.atttypmod - 4 end::information_schema.cardinal_number as character_maximum_length,
                case pg_attribute.attnotnull when false then 'YES' else 'NO' end::information_schema.yes_or_no as is_nullable,
                case when pk.contype is null then 'NO' else 'YES' end::information_schema.yes_or_no as is_pk,
                case when fk.table_oid is null then 'NO' else 'YES' end::information_schema.yes_or_no as is_fk,
                fk.f_table_name::information_schema.sql_identifier,
                fk.f_column_name::information_schema.sql_identifier
        from pg_tables
        join pg_class
          on pg_class.relname = pg_tables.tablename
        join pg_namespace ns
          on ns.oid = pg_class.relnamespace
         and ns.nspname  = pg_tables.schemaname
        join pg_attribute
          on pg_class.oid = pg_attribute.attrelid
         and pg_attribute.attnum > 0
        left join pg_constraint pk
          on pk.contype = 'p'::"char"
         and pk.conrelid = pg_class.oid
         and (pg_attribute.attnum = any (pk.conkey))
        left join clearing_house.view_foreign_keys as fk
          on fk.table_oid = pg_class.oid
         and fk.attnum = pg_attribute.attnum
        where true
          and pg_tables.tableowner = p_owner
          and pg_attribute.atttypid <> 0::oid
          and pg_tables.schemaname = p_schema_name
        order by table_name, ordinal_position asc;
end
$body$;

/*********************************************************************************************************************************
**  View        view_clearinghouse_sead_rdb_schema_pk_columns
**  When        2013-10-18
**  What        Returns PK column name for RDB tables
**  Who         Roger Mähler
**  Uses        INFORMATION_SCHEMA.catalog in SEAD production
**  Used By     Clearing House installation. DBA.
**  Revisions
**********************************************************************************************************************************/
-- Create Or Replace view clearing_house.view_clearinghouse_sead_rdb_schema_pk_columns as
--     Select table_schema, table_name, column_name
--     From clearing_house.fn_dba_get_sead_public_db_schema('public', 'sead_master')
--     Where is_pk = 'YES'
-- ;

/*********************************************************************************************************************************
**  Function    fn_sead_entity_tables
**  When
**  What        Maps table names to entity names
**  Who         Roger Mähler
**  Uses
**  Used By     NOT USED. DEPRECATED!
**  Revisions
**********************************************************************************************************************************/
-- CREATE OR REPLACE FUNCTION clearing_house.fn_sead_entity_tables()
-- RETURNS TABLE (
--     table_name information_schema.sql_identifier,
--     entity_name information_schema.sql_identifier
-- ) LANGUAGE 'plpgsql'
-- AS $BODY$
-- Begin
-- 	Return Query
-- 		With tables as (
-- 			SELECT DISTINCT r.table_name, replace(r.table_name, 'tbl_', '') as plural_entity_name
-- 			FROM clearing_house.fn_dba_get_sead_public_db_schema('public', 'sead_master') r
-- 			WHERE r.table_name Like 'tbl_%'
-- 			  AND r.is_pk = 'YES' /* Måste finnas PK */
-- 		) Select t.table_name::information_schema.sql_identifier,
-- 			Case When plural_entity_name Like  '%ies' Then regexp_replace(plural_entity_name, 'ies$', 'y')
-- 		 		 When Not plural_entity_name Like '%status' Then rtrim(plural_entity_name, 's')
-- 				 Else plural_entity_name End::information_schema.sql_identifier As entity_name
-- 		  From tables t;
-- End
-- $BODY$;
