/*****************************************************************************************************************************
**	Function	fn_create_gateways/
**	Who			Roger Mähler
**	When		2019-04-19
**	What		Creates gateway table and triggers for CH data submit
**  Note        A skeleton trigger function is created
**  Uses
**  Used By
**	Revisions
******************************************************************************************************************************/
-- Select clearing_house_commit.fn_generate_transport_gateways()
-- Drop Function clearing_house_commit.fn_generate_transport_gateway(name, name, name);
Create Or Replace Function clearing_house_commit.fn_generate_transport_gateway(p_target_schema name, p_table_name name, v_pk_name name, p_entity_name name)
Returns text As $$
	Declare
        v_sql text = '';
	    v_sql_script text = '';
        v_gateway_name text = '';
        v_template text;
Begin

    v_template     = '

        drop trigger if exists [ENTITY_NAME]_transport_trigger on clearing_house_commit.[ENTITY_NAME]_gateway;
        drop function if exists clearing_house_commit.transport_[ENTITY_NAME]();
        drop view if exists clearing_house_commit.[ENTITY_NAME]_gateway cascade;

        -- create table clearing_house_commit.[ENTITY_NAME]_gateway (like public.[TABLE_NAME]
        --    including constraints including indexes including defaults);

        create or replace view clearing_house_commit.[ENTITY_NAME]_gateway as
            select *
            from [TARGET_SCHEMA_NAME].[TABLE_NAME]
            where false;

        create or replace function clearing_house_commit.transport_[ENTITY_NAME]() returns trigger as $X$
            begin

                if TG_OP <> ''INSERT'' then
                    raise exception ''TG_OP % unexpected. INSERT is only supported TG_OP!'', TG_OP;
                end if;

                insert into [TARGET_SCHEMA_NAME].[TABLE_NAME] values (NEW);

                return null;

            end;
        $X$ language plpgsql;

        create trigger [ENTITY_NAME]_transport_trigger
            instead of insert or update or delete on clearing_house_commit.[ENTITY_NAME]_gateway
                for each row execute procedure clearing_house_commit.transport_[ENTITY_NAME]();

    ';

    v_sql = replace(v_template, '[TARGET_SCHEMA_NAME]', p_target_schema);
    v_sql = replace(v_sql, '[ENTITY_NAME]', p_entity_name);
    v_sql = replace(v_sql, '[TABLE_NAME]', p_table_name);

    return v_sql;

End $$ Language plpgsql;

-- Select clearing_house_commit.fn_generate_transport_gateways(FALSE)
-- Drop Function clearing_house_commit.fn_generate_transport_gateways(boolean);
create or replace function clearing_house_commit.fn_generate_transport_gateways(p_dry_run boolean=true)
returns setof text as $$
	declare v_schema_name name;
	declare v_table_name name;
	declare v_entity_name name;
    declare v_pk_name name;
	declare sql_script text;
begin
	for v_schema_name, v_table_name, v_pk_name, v_entity_name in (
        select table_schema as schema_name,
               table_name,
               column_name,
               clearing_house.fn_sead_table_entity_name(table_name::name)
		from clearing_house.fn_dba_get_sead_public_db_schema()
		where is_pk = 'YES'
		order by 2, 3
	)
	loop
        --sql_script = format('alter table clearing_house.%s rename column transport_crud_type to transport_type;', v_table_name);
        sql_script = format('alter table clearing_house.%s alter column transport_id type int using transport_id::int;', v_table_name);
        --sql_script = clearing_house_commit.fn_generate_transport_gateway(v_schema_name, v_table_name, v_pk_name, v_entity_name);
		if (not p_dry_run) then
		    execute sql_script;
		end if;
        return next sql_script;
	end loop;
end $$ language plpgsql;
