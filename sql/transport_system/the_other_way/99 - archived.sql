do $$
begin
    -- drop type if exists sead_id_range;
    if not exists (select 1 from pg_type where typname = 'sead_id_range') then
        create type sead_id_range as (
          id_low  int,
          id_high int
        );
    end if;

end$$;

/*****************************************************************************************************************************************
** Function get_new_entities_count
** Returns  Number of new entities in submission for given table
******************************************************************************************************************************************/

-- drop function if exists get_new_entities_count(int, name)
-- select get_new_entities_count(3, 'tbl_sites')
create or replace function get_new_entities_count(p_submission_id int, p_tablename name) returns int as $$
declare
    v_count int;
begin
    execute format('
        select count(*)
        from clearing_house.%s
        where submission_id = %s
          and public_db_id is null;',
        p_tablename, p_submission_id
    ) into v_count;
    return v_count;
end;$$ language plpgsql;

-- drop function if exists fn_allocate_id_range(character varying, character varying, int)
create or replace function fn_allocate_id_range(p_table_name character varying, p_column_name character varying, p_count int)
    returns sead_id_range language plpgsql as $$
declare
    v_range sead_id_range;
    v_sequence_name character varying;
begin
    v_sequence_name = pg_get_serial_sequence(p_table_name, p_column_name);
    -- todo: sync sequence first
    -- this doesn't work, currval = last nextval() in current session
    -- must do "select last_value from sequence" instead
    v_range.id_low  = currval(v_sequence_name);
    v_range.id_high = v_range.id_low + p_count;
    raise notice '%', v_range.id_low;
    perform setval(v_sequence_name, v_range.id_high);
    v_range.id_high = currval(v_sequence_name);
    raise notice '%', v_range.id_high;
    return v_range;
end $$;
