INSERT INTO clearing_house_commit.tbl_abundance_elements(abundance_element_id, record_type_id, element_name, element_description, date_updated)
	VALUES (2, 1, 'Roger', 'Mähler', now());

select * from clearing_house_commit.tbl_abundance_elements;


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 5689 (class 0 OID 23397)
-- Dependencies: 193
-- Data for Name: tbl_abundance_elements; Type: TABLE DATA; Schema: public; Owner: sead_master
--

COPY public.tbl_abundance_elements (abundance_element_id, record_type_id, element_name, element_description, date_updated) FROM stdin;
1	1	Whole arthropod	A complete, or near complete, insect or similar individual	2012-09-21 18:51:47.967181+02
2	2	Pollen grain	Whole or partial pollen grain	2012-09-21 18:51:47.967181+02
3	2	Leaf	Whole or partial leaf	2012-09-21 18:51:47.967181+02
4	2	Seed grain	An individual or partial sead grain	2012-09-21 18:51:47.967181+02
5	1	MNI	Minimum Number of Individuals - an estimation of the number of whole animals represented by the collective parts found.	2012-09-21 18:51:47.967181+02
6	1	Left elytron	Left wing case.	2012-09-21 18:51:47.967181+02
7	1	Right elytron	Right wing case.	2012-09-21 18:51:47.967181+02
8	1	Thorax	\N	2012-09-21 18:51:47.967181+02
9	1	Head	\N	2012-09-21 18:51:47.967181+02
10	1	Body segment (other)	\N	2012-09-21 18:51:47.967181+02
\.



do $$
declare
    v_filename varchar = E'/tmp/tbl_abundance_elements.sql';
begin

    begin

        copy (select * from  public.tbl_abundance_elements)
            to v_filename
                with (format csv, encoding 'utf8');

        delete from clearing_house_commit.tbl_abundance_elements;

        copy clearing_house_commit.tbl_abundance_elements
           from v_filename
                with (format csv, encoding 'utf8');

    exception
        when sqlstate '58P01' then
            raise notice 'FILE NOT FOUND! FILE MUST EXIST ON SERVER! ';
        when sqlstate '22P02' then
            raise notice 'INVALID FORMAT!';
        when sqlstate '23505' then
            raise notice 'duplicate key value violation!';
    end;

end $$;



select pg_read_file(E'/tmp/tbl_abundance_elements.sql')

-- COPY table_name [ ( column_name [, ...] ) ]
--     FROM { 'filename' | STDIN }
--     [ [ WITH ] ( option [, ...] ) ]

-- COPY { table_name [ ( column_name [, ...] ) ] | ( query ) }
--     TO { 'filename' | STDOUT }
--     [ [ WITH ] ( option [, ...] ) ]

-- where option can be one of:

--     FORMAT format_name
--     OIDS [ boolean ]
--     DELIMITER 'delimiter_character'
--     NULL 'null_string'
--     HEADER [ boolean ]
--     QUOTE 'quote_character'
--     ESCAPE 'escape_character'
--     FORCE_QUOTE { ( column_name [, ...] ) | * }
--     FORCE_NOT_NULL ( column_name [, ...] )
--     ENCODING 'UTF8'
select uuid_generate_v4()::text

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";


-- drop function if exists clearing_house_commit.read_file_utf8(character varying);
create or replace function clearing_house_commit.read_file_utf8(p_path character varying)
    returns text as $$
declare
    v_file_oid oid;
    v_record   record;
    v_result   bytea := '';
begin
    select lo_import(p_path)
        into v_file_oid;
    for v_record in (
        select data
        from pg_largeobject
        where loid = v_file_oid
        order by pageno)
    loop
        v_result = v_result || v_record.data;
    end loop;
    perform lo_unlink(v_file_oid);
    return convert_from(v_result, 'utf8');
end;
$$ language plpgsql;

-- drop function if exists clearing_house_commit.fn_export_data(text, character varying);
create or replace function clearing_house_commit.fn_export_data(p_source text, p_path character varying) returns text as $$
    declare v_data text = '';
begin
    execute format('copy %s to ''%s'' with (format csv, encoding ''utf8'');', p_source, p_path);
    v_data = clearing_house_commit.read_file_utf8(p_path);
    return v_data;
end $$ language plpgsql;

select clearing_house_commit.fn_export_data('(select * from  public.tbl_abundance_elements)', E'/tmp/tbl_abundance_elements.sql');

copy (select * from  public.tbl_abundance_elements)
    to v_filename
        with (format csv, encoding 'utf8');

do $$
declare
    v_filename varchar = E'/tmp/tbl_abundance_elements.sql';
begin

    begin

        copy (select * from  public.tbl_abundance_elements)
            to v_filename
                with (format csv, encoding 'utf8');

        delete from clearing_house_commit.tbl_abundance_elements;

        copy clearing_house_commit.tbl_abundance_elements
           from v_filename
                with (format csv, encoding 'utf8');

    exception
        when sqlstate '58P01' then
            raise notice 'FILE NOT FOUND! FILE MUST EXIST ON SERVER! ';
        when sqlstate '22P02' then
            raise notice 'INVALID FORMAT!';
        when sqlstate '23505' then
            raise notice 'duplicate key value violation!';
    end;

end $$;

select length(clearing_house_commit.fn_read_text('/tmp/tbl_abundance_elements.sql'));


-- drop function if exists clearing_house_commit.fn_read_text(text, text);
-- create or replace function clearing_house_commit.fn_read_text(p_filename text) returns text as $$
-- declare v_sql text = '';
--     v_tablename name;
--     v_content text;
-- begin
--     v_tablename = quote_ident(uuid_generate_v4()::name);
--     execute format('create temp table %s (content text)', v_tablename);
--     execute format('copy %s from ''%s''', v_tablename, p_filename);
--     execute format('select content from %s', v_tablename) into v_content;
--     execute format('drop table %s', v_tablename);

--     return v_content;
-- end $$ language plpgsql;

select clearing_house_commit.read_file_utf8('/tmp/tbl_abundance_elements.sql');
