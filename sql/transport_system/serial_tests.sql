/*
create table if not exists a_table (
    table_id serial primary key
);
INSERT INTO a_table (table_id) VALUES (DEFAULT) RETURNING table_id;
ALTER SEQUENCE teams_id_seq RESTART WITH 31;
   
ALTER SEQUENCE public.a_table_table_id_seq RESTART WITH 3 INCREMENT BY 3;
SELECT currval('teams_id_seq');
SELECT setval('teams_id_seq');
SELECT lastval()
*/
/*
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'sead_id_range') THEN
        CREATE TYPE sead_id_range as (
          id_low  int,
          id_high int
        );
    END IF;

END$$;

create or replace function allocate_id_range(p_table_name varchar, p_column_name varchar, p_count int) returns int language plpgsql as $$
declare
    v_range sead_id_range;
    v_sequence_name varchar;
begin
    v_sequence_name = pg_get_serial_sequence(p_table_name, p_column_name);
    -- todo: sync sequence first
    v_range.id_low  = currval(v_sequence_name);
    v_range.id_high = v_range.id_low + p_count;
    raise notice '%', v_range.id_low;
    perform setval(v_sequence_name, v_range.id_high);
    v_range.id_high = currval(v_sequence_name);
    raise notice '%', v_range.id_high;
    return v_range;
end $$;
*/
select pg_get_serial_sequence('public.tbl_biblio', 'biblio_id');