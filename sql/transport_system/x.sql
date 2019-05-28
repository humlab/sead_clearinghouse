set session schema 'clearing_house_commit';

create or replace function resolve_foreign_key(p_table_name character varying) returns text as $$
declare
    v_sql text = '';
    v_entity_name character varying = '';
begin

    v_entity_name = clearing_house.fn_sead_table_entity_name(p_table_name::name);
    
--            select  *, clearing_house.fn_sead_table_entity_name('tbl_sample_groups'::name) as entity_name
--                     case when is_pk = 'yes'  then
--                         format(pk_field_template, column_name)
--                     when is_fk = 'yes' then
--                         format(fk_field_template, ordinal_position, ordinal_position, column_name)
--                     else
--                         'e.' || column_name
--                     end as field_clause,

--                     case when is_fk = 'yes' then
--                         format(join_clause_template, fk_table_name, ordinal_position, column_name, ordinal_position)
--                     else
--                         null
--                     end as join_clause
--            from clearing_house.fn_dba_get_sead_public_db_schema()

    return v_sql;

end $$ language plpgsql;

select resolve_foreign_key('tbl_sample_groups');