
-- Insert SITES


/* Update existing SITES */
-- REGEL: TILLÅT INTE 

Update p
	Set -- LIST OF UPDATES
From table_sites p_t
Join clearing_house.tbl_sites l_t
  On p_t.site_id = l_t.public_id
Where p.site_id = p_t.site_id
  
Select count(*) From clearing_house.tbl_clearinghouse_submissions
From clearing_house.tbl_sites l_t

/*

1. LOOKUPS HANTERAS I EGET FLÖDE
2. TILLÅT INTE UPPDATERING AV FK?
3. SKAPA ALLTID NYTT DATASET NÄR DATA UPPDATERAS

*/
--create type a_test as ( a boolean, b char(32) );
--create type b_test as ( a boolean, b char(32), c int );

do $$
declare a a_test; b b_test; x public.tbl_sites;
begin
   a = row(TRUE, 'Roger');
   b = row(FALSE, 'Kalle', 10);
   
   a := b;
   
   raise info '%', a;

end $$ 
language plpgsql;

drop type a_test;
drop type b_test;

do $$
declare
	a_site clearing_house.tbl_sites;
	b_site public.tbl_sites;
begin
	select * into a_site from clearing_house.tbl_sites limit 1;
	b_site = a_site;
	raise info '%', a_site;
	--raise info '%', b;
	--insert into public.tbl_sites select (b_site).*;
	--raise exception 'OK';
end $$ 
language plpgsql;

--select * from public.tbl_sites limit 1;
select * from clearing_house.tbl_sites limit 1;

/*
select a.table_name, a.column_name, a.ordinal_position - 4, b.column_name, b.ordinal_position
from information_schema.columns a
left join information_schema.columns b
  on a.table_name = b.table_name
 and a.column_name = b.column_name
 and b.table_schema = 'public'
where a.table_schema = 'clearing_house'
  and a.table_name = 'tbl_sites'
order by coalesce(a.ordinal_position, b.ordinal_position);
*/

select * from information_schema.columns a where table_name = 'tbl_sites'

-- DROP TRIGGER IF EXISTS trigger_test_sites ON public.tbl_test_sites;
-- DROP FUNCTION IF EXISTS public.fn_trigger_test_sites();
-- DROP VIEW IF EXISTS public.tbl_test_sites;

-- CREATE VIEW tbl_test_sites AS
-- 	SELECT *
-- 	FROM clearing_house.tbl_sites
-- 	WHERE FALSE;

CREATE OR REPLACE FUNCTION public.fn_trigger_test_sites() RETURNS TRIGGER AS $body$
DECLARE
	v_site public.tbl_sites;
BEGIN

	RAISE NOTICE 'TG_OP: %', TG_OP;
	RAISE NOTICE 'TG_NAME: %', TG_NAME;
	RAISE NOTICE 'TG_WHEN: %', TG_WHEN;
	RAISE NOTICE 'TG_LEVEL: %', TG_LEVEL;
	RAISE NOTICE 'TG_RELID: %', TG_RELID;
	RAISE NOTICE 'TG_RELNAME: %', TG_RELNAME;
	RAISE NOTICE 'TG_TABLE_NAME: %', TG_TABLE_NAME;
	RAISE NOTICE 'TG_TABLE_SCHEMA: %', TG_TABLE_SCHEMA;
	RAISE NOTICE 'TG_NARGS: %', TG_NARGS;
	RAISE NOTICE 'TG_ARGV: %', TG_ARGV;

	-- v_site = NEW;
	
	RAISE NOTICE 'NEW: %', NEW;
	RAISE NOTICE 'v_site: %', v_site;
	-- RAISE NOTICE 'OLD: %', OLD;
	
	RETURN NULL;
END;
$body$
LANGUAGE plpgsql;

-- DROP TRIGGER IF EXISTS trigger_test_sites ON public.tbl_test_sites;

-- CREATE TRIGGER trigger_test_sites
-- 	INSTEAD OF INSERT OR UPDATE OR DELETE ON public.tbl_test_sites
-- 		FOR EACH ROW EXECUTE PROCEDURE public.fn_trigger_test_sites();

INSERT INTO public.tbl_test_sites
 	SELECT *
 	FROM clearing_house.tbl_sites
 	LIMIT 1;

-- DROP TRIGGER IF EXISTS trigger_test_sites ON public.tbl_test_sites;
-- DROP FUNCTION IF EXISTS public.fn_trigger_test_sites();
-- DROP VIEW IF EXISTS public.tbl_test_sites;
