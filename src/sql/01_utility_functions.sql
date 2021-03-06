/*****************************************************************************************************************************
**	Function	fn_DD2DMS
**	Who			Roger Mähler
**	When		2013-10-14
**	What		Converts geoposition DD to DMS
**	Uses
**	Used By     DEPREACTED - NOT USED
**	Revisions
******************************************************************************************************************************/
Create Or Replace Function clearing_house.fn_DD2DMS(
	p_dDecDeg       IN float,
    p_sDegreeSymbol IN varchar(1) = 'd',
    p_sMinuteSymbol IN varchar(1) = 'm',
    p_sSecondSymbol IN varchar(1) = 's'
) Returns VARCHAR(50) As $$
Declare
   v_iDeg int;
   v_iMin int;
   v_dSec float;
Begin
   v_iDeg := Trunc(p_dDecDeg)::INT;
   v_iMin := Trunc((Abs(p_dDecDeg) - Abs(v_iDeg)) * 60)::int;
   v_dSec := Round(((((Abs(p_dDecDeg) - Abs(v_iDeg)) * 60) - v_iMin) * 60)::numeric, 3)::float;
   Return trim(to_char(v_iDeg,'9999')) || p_sDegreeSymbol::text || trim(to_char(v_iMin,'99')) || p_sMinuteSymbol::text ||
          Case When v_dSec = 0::FLOAT Then '0' Else replace(trim(to_char(v_dSec,'99.999')),'.000','') End || p_sSecondSymbol::text;
End $$ Language plpgsql;

/*****************************************************************************************************************************
**	Function	fn_pascal_case_to_underscore i.e. pascal/camel_case_to_snake_case
**	Who			Roger Mähler
**	When		2013-10-14
**	What		Converts PascalCase to pascal_case
**	Uses
**	Used By
**	Revisions   Add underscore before digits as well e.g. "address1" becomes "address_1"
**              previously: lower(Left(p_token, 1) || regexp_replace(substring(p_token from 2), E'([A-Z])', E'\_\\1','g'));
******************************************************************************************************************************/
-- Select fn_pascal_case_to_underscore('c14AgeOlder'), clearing_house.fn_pascal_case_to_underscore('address1');
Create Or Replace Function clearing_house.fn_pascal_case_to_underscore(p_token character varying(255))
Returns character varying(255) As $$
Begin
    return lower(regexp_replace(p_token,'([[:lower:]]|[0-9])([[:upper:]]|[0-9]$)','\1_\2','g'));
End $$ Language plpgsql;

/*****************************************************************************************************************************
**	Function	fn_java_type_to_PostgreSQL
**	Who			Roger Mähler
**	When		2013-10-14
**	What		Converts Java type to PostgreSQL data type
**	Uses
**	Used By
**	Revisions
******************************************************************************************************************************/
-- Select fn_pascal_case_to_underscore('RogerMahler')
create or replace function clearing_house.fn_java_type_to_postgresql(s_type_name character varying)
    returns character varying language 'plpgsql'
AS $BODY$
Begin
	If (lower(s_type_name) in ('java.util.date', 'java.sql.date')) Then
		return 'date';
	End If;

	If (lower(s_type_name) in ('java.math.bigdecimal', 'java.lang.double')) Then
		return 'numeric';
	End If;

	If (lower(s_type_name) in ('java.lang.integer', 'java.util.integer', 'java.long.short')) Then
		return 'integer';
	End If;

	If (lower(s_type_name) = 'java.lang.boolean') Then
		return 'boolean';
	End If;

	If (lower(s_type_name) in ('java.lang.string', 'java.lang.character')) Then
		return 'text';
	End If;

	If (s_type_name Like 'com.sead.database.Tbl%' or s_type_name Like 'Tbl%') Then
		return 'integer'; /* FK */
	End If;

	Raise Exception 'Fatal error: Java type % encountered in XML not expected', s_type_name;
End
$BODY$;

/*****************************************************************************************************************************
**	Function	fn_table_exists
**	Who			Roger Mähler
**	When		2013-10-14
**	What		Checks if table exists in current DB-schema
**	Uses
**	Used By
**	Revisions
******************************************************************************************************************************/
-- Select fn_table_exists('tbl_submission_xml_content_meta_tables')
create or replace function clearing_house.fn_table_exists(p_table_name character varying(255))
returns boolean as $$
	declare exists boolean;
begin
	Select Count(*) > 0 Into exists
		From information_schema.tables
		Where table_catalog = CURRENT_CATALOG
		  And table_schema = CURRENT_SCHEMA
		  And table_name = p_table_name;
	return exists;
end $$ language plpgsql;

/*****************************************************************************************************************************
**	Function	fn_get_entity_type_for
**	Who			Roger Mähler
**	When		2013-10-14
**	What		Returns entity type for table
**	Uses
**	Used By
**	Revisions
******************************************************************************************************************************/
-- Select clearing_house.fn_get_entity_type_for('tbl_sites')
Create Or Replace Function clearing_house.fn_get_entity_type_for(p_table_name character varying(255))
Returns int As $$
Declare
    table_entity_type_id int;
Begin

    Select x.entity_type_id
        Into table_entity_type_id
    From clearing_house.tbl_clearinghouse_reject_entity_types x
    Join clearing_house.tbl_clearinghouse_submission_tables t
      On x.table_id = t.table_id
    Where table_name_underscored = p_table_name;

    Return Coalesce(table_entity_type_id,0);
End $$ Language plpgsql;

/*****************************************************************************************************************************
**	Function	xml_transfer_bulk_upload
**	Who			Roger Mähler
**	When		2017-10-26
**	What
**	Uses
**	Used By     DEPRECATED NOT USED!
**	Revisions
******************************************************************************************************************************/
-- Select * from clearing_house.tbl_clearinghouse_submissions where not xml is null
-- Select clearing_house.xml_transfer_bulk_upload(1)
Create Or Replace Function clearing_house.xml_transfer_bulk_upload(p_submission_id int = null, p_xml_id int = null, p_upload_user_id int = 4)
Returns int As $$
Begin
	p_xml_id = Coalesce(p_xml_id, (Select Max(ID) from clearing_house.tbl_clearinghouse_xml_temp));
	If p_submission_id Is Null Then

        Select Coalesce(Max(submission_id),0) + 1
        Into p_submission_id
        From clearing_house.tbl_clearinghouse_submissions;

        Insert Into clearing_house.tbl_clearinghouse_submissions(
            submission_id, submission_state_id, data_types, upload_user_id,
            upload_date, upload_content, xml, status_text, claim_user_id, claim_date_time
        )
            Select p_submission_id, 1, 'Undefined other', p_upload_user_id, now(), null, xmldata, 'New', null, null
            From clearing_house.tbl_clearinghouse_xml_temp
            Where id = p_xml_id;
    Else
		Update clearing_house.tbl_clearinghouse_submissions
        	Set XML = X.xmldata
        From clearing_house.tbl_clearinghouse_xml_temp X
        Where clearing_house.tbl_clearinghouse_submissions.submission_id = p_submission_id
          And X.id = p_xml_id;
    End If;
    Return p_submission_id;
End $$ Language plpgsql;

/*****************************************************************************************************************************
**	Function	fn_sead_table_entity_name
**	Who			Roger Mähler
**	When		2018-10-21
**	What        Computes a noun from a sead table name in singular form
**	Uses
**	Used By     Clearinghouse transfer & commit
**	Revisions
******************************************************************************************************************************/
create or replace function clearing_house.fn_sead_table_entity_name(p_table_name text)
returns information_schema.sql_identifier as $$
begin
	return Replace(Case When p_table_name Like  '%ies' Then regexp_replace(p_table_name, 'ies$', 'y')
		 When Not p_table_name Like '%status' Then rtrim(p_table_name, 's')
		 Else p_table_name End, 'tbl_', '')::information_schema.sql_identifier As entity_name;
end; $$ language plpgsql;

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

create or replace function clearing_house.chown(in_schema character varying, new_owner character varying)
  returns void
as $$
declare
  object_types varchar[];
  object_classes varchar[];
  object_type record;
  r record;
begin
  object_types = '{type,table,table,sequence,index,view}';
  object_classes = '{c,t,r,S,i,v}';

  for object_type in
      select unnest(object_types) type_name,
                unnest(object_classes) code
  loop
    for r in
          select n.nspname, c.relname
          from pg_class c, pg_namespace n
          where n.oid = c.relnamespace
            and nspname = in_schema
            and relkind = object_type.code
    loop
      raise notice 'Changing ownership of % %.% to %',
                  object_type.type_name,
                  r.nspname, r.relname, new_owner;
      execute format(
        'alter %s %I.%I owner to %I'
        , object_type.type_name, r.nspname, r.relname,new_owner);
    end loop;
  end loop;

  for r in
    select  p.proname, n.nspname,
       pg_catalog.pg_get_function_identity_arguments(p.oid) args
    from    pg_catalog.pg_namespace n
    join    pg_catalog.pg_proc p
    on      p.pronamespace = n.oid
    where   n.nspname = in_schema
  loop
    raise notice 'Changing ownership of function %.%(%) to %',
                 r.nspname, r.proname, r.args, new_owner;
    execute format(
       'alter function %I.%I (%s) owner to %I', r.nspname, r.proname, r.args, new_owner);
  end loop;

  for r in
    select *
    from pg_catalog.pg_namespace n
    join pg_catalog.pg_ts_dict d
      on d.dictnamespace = n.oid
    where n.nspname = in_schema
  loop
    execute format(
       'alter text search dictionary %I.%I owner to %I', r.nspname, r.dictname, new_owner );
  end loop;
end $$ language plpgsql;
