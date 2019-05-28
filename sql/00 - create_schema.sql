/*****************************************************************************************************************************
**	What		User defined types and domains
**	Uses
**	Used By
**	Revisions
******************************************************************************************************************************/
do $$
begin
   if not exists (select from pg_catalog.pg_roles where rolname = 'clearinghouse_worker') then
        raise notice 'create clearinghouse_worker must be run as superuser';
        raise exception 'clearinghouse_worker does NOT exist';
   else
        raise notice 'clearinghouse_worker exists';
   end if;
end $$ language plpgsql;

/*****************************************************************************************************************************
**	Create "clearing_house" schema
******************************************************************************************************************************/

do $$
begin
    drop schema if exists clearing_house cascade;

    create schema clearing_house authorization clearinghouse_worker;

    create domain clearing_house.transport_type char
        check (value is null or value in ('C', 'U', 'D')) default null null;

end $$ language plpgsql;
