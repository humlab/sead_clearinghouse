
/***************************************************************************
Author         roger
Date           
Description    
Prerequisites  
Reviewer
Approver
Idempotent     YES
Notes          Use --single-transactin on execute!
***************************************************************************/
--set constraints all deferred;
set client_min_messages to warning;
-- set autocommit off;
-- begin;
create schema if not exists clearing_house authorization clearinghouse_worker;

alter user clearinghouse_worker createdb;

grant usage on schema public, sead_utility to clearinghouse_worker;
grant all privileges on all tables in schema public, sead_utility to clearinghouse_worker;
grant all privileges on all sequences in schema public, sead_utility to clearinghouse_worker;
grant execute on all functions in schema public, sead_utility to clearinghouse_worker;

alter default privileges in schema public, sead_utility
grant all privileges on tables to clearinghouse_worker;
alter default privileges in schema public, sead_utility
grant all privileges on sequences to clearinghouse_worker;
﻿/*****************************************************************************************************************************
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

CREATE OR REPLACE FUNCTION clearing_house.chown(in_schema character varying, new_owner character varying)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
  object_types VARCHAR[];
  object_classes VARCHAR[];
  object_type record;

  r record;
BEGIN
  object_types = '{type,table,table,sequence,index,view}';
  object_classes = '{c,t,r,S,i,v}';

  FOR object_type IN
      SELECT unnest(object_types) type_name,
                unnest(object_classes) code
  loop
    FOR r IN
      EXECUTE format('
          select n.nspname, c.relname
          from pg_class c, pg_namespace n
          where n.oid = c.relnamespace
            and nspname = %I
            and relkind = %L',in_schema,object_type.code)
    loop
      raise notice 'Changing ownership of % %.% to %',
                  object_type.type_name,
                  r.nspname, r.relname, new_owner;
      EXECUTE format(
        'alter %s %I.%I owner to %I'
        , object_type.type_name, r.nspname, r.relname,new_owner);
    END loop;
  END loop;

  FOR r IN
    SELECT  p.proname, n.nspname,
       pg_catalog.pg_get_function_identity_arguments(p.oid) args
    FROM    pg_catalog.pg_namespace n
    JOIN    pg_catalog.pg_proc p
    ON      p.pronamespace = n.oid
    WHERE   n.nspname = in_schema
  LOOP
    raise notice 'Changing ownership of function %.%(%) to %',
                 r.nspname, r.proname, r.args, new_owner;
    EXECUTE format(
       'alter function %I.%I (%s) owner to %I', r.nspname, r.proname, r.args, new_owner);
  END LOOP;

  FOR r IN
    SELECT *
    FROM pg_catalog.pg_namespace n
    JOIN pg_catalog.pg_ts_dict d
      ON d.dictnamespace = n.oid
    WHERE n.nspname = in_schema
  LOOP
    EXECUTE format(
       'alter text search dictionary %I.%I owner to %I', r.nspname, r.dictname, new_owner );
  END LOOP;
END;
$function$
/*********************************************************************************************************************************
**  Function    create_clearinghouse_model
**  When        2013-10-17
**  What        Creates DB clearing_house specific schema objects (not entity objects) for Clearing House application
**  Who         Roger Mähler
**  Note
**  Uses
**  Used By     Clearing House server installation. DBA.
**  Revisions
**********************************************************************************************************************************/
-- Select clearing_house.fn_dba_create_clearing_house_db_model();
-- Drop Function If Exists fn_dba_create_clearing_house_db_model(BOOLEAN);
Create Or Replace Procedure clearing_house.create_clearinghouse_model(p_drop_tables BOOLEAN=FALSE) As $$

Begin

	if (p_drop_tables) Then

		Drop Table If Exists clearing_house.tbl_clearinghouse_activity_log;
		Drop Table If Exists clearing_house.tbl_clearinghouse_submissions;
		Drop Table If Exists clearing_house.tbl_clearinghouse_signal_log;

		Drop Table If Exists clearing_house.tbl_clearinghouse_submissions;
		Drop Table If Exists clearing_house.tbl_clearinghouse_reject_cause_types;
		Drop Table If Exists clearing_house.tbl_clearinghouse_reject_causes;
		Drop Table If Exists clearing_house.tbl_clearinghouse_users;
		Drop Table If Exists clearing_house.tbl_clearinghouse_user_roles;
		Drop Table If Exists clearing_house.tbl_clearinghouse_data_provider_grades;
		Drop Table If Exists clearing_house.tbl_clearinghouse_submission_states;

	End If;

	If (p_drop_tables) Then

		Drop Table If Exists clearing_house.tbl_clearinghouse_submission_xml_content_values;
		Drop Table If Exists clearing_house.tbl_clearinghouse_submission_xml_content_records;
		Drop Table If Exists clearing_house.tbl_clearinghouse_submission_xml_content_columns;
		Drop Table If Exists clearing_house.tbl_clearinghouse_submission_xml_content_tables;
		Drop Table If Exists clearing_house.tbl_clearinghouse_submission_tables;

	End If;

    Create Table If Not Exists clearing_house.tbl_clearinghouse_settings (
        setting_id serial not null,
        setting_group character varying(255) not null,
        setting_key character varying(255) not null,
        setting_value text not null,
        setting_datatype text not null,
        Constraint pk_tbl_clearinghouse_settings Primary Key (setting_id)
    );

    Drop Index If Exists clearing_house.idx_tbl_clearinghouse_settings_key;
    create unique index idx_tbl_clearinghouse_settings_key On clearing_house.tbl_clearinghouse_settings (setting_key);

    Drop Index If Exists clearing_house.idx_tbl_clearinghouse_settings_group;
    create index idx_tbl_clearinghouse_settings_group On clearing_house.tbl_clearinghouse_settings (setting_group);

    Create Table If Not Exists clearing_house.tbl_clearinghouse_info_references (
        info_reference_id serial not null,
        info_reference_type character varying(255) not null,
        display_name character varying(255) not null,
        href character varying(255),
        Constraint pk_tbl_clearinghouse_info_references Primary Key (info_reference_id)
    );

    Create Table If Not Exists clearing_house.tbl_clearinghouse_sessions (
        session_id serial not null,
        user_id int not null default(0),
        ip character varying(255),
        start_time date not null,
        stop_time date,
        Constraint pk_tbl_clearinghouse_sessions_session_id Primary Key (session_id)
    );

    Create Table If Not Exists clearing_house.tbl_clearinghouse_signals (
        signal_id serial not null,
        use_case_id int not null default(0),
        recipient_user_id int not null default(0),
        recipient_address text not null,
        signal_time date not null,
        subject text,
        body text,
        status text,
        Constraint pk_clearinghouse_signals_signal_id Primary Key (signal_id)
    );

    /*********************************************************************************************************************************
    ** Activity
    **********************************************************************************************************************************/

    Create Table If Not Exists clearing_house.tbl_clearinghouse_use_cases (
        use_case_id int not null,
        use_case_name character varying(255) not null,
        entity_type_id int not null default(0),
        Constraint pk_tbl_clearinghouse_use_cases PRIMARY KEY (use_case_id)
    );

    Create Table If Not Exists clearing_house.tbl_clearinghouse_activity_log (
        activity_log_id serial not null,
        use_case_id int not null default(0),
        user_id int not null default(0),
        session_id int not null default(0),
        entity_type_id int not null default(0),
        entity_id int not null default(0),
        execute_start_time date not null,
        execute_stop_time date,
        status_id int not null default(0),
        activity_data text null,
        message text not null default(''),
        Constraint pk_activity_log_id PRIMARY KEY (activity_log_id)
    );

    Drop Index If Exists clearing_house.idx_clearinghouse_activity_entity_id;
    Create Index idx_clearinghouse_activity_entity_id
        On clearing_house.tbl_clearinghouse_activity_log (entity_type_id, entity_id);

    Create Table If Not Exists clearing_house.tbl_clearinghouse_signal_log (
        signal_log_id serial not null,
        use_case_id int not null,
        signal_time date not null,
        email text not null,
        cc text not null,
        subject text not null,
        body text not null,
        Constraint pk_signal_log_id PRIMARY KEY (signal_log_id)
    );

    /*********************************************************************************************************************************
    ** Users
    **********************************************************************************************************************************/

    Create Table If Not Exists clearing_house.tbl_clearinghouse_data_provider_grades (
        grade_id int not null,
        description character varying(255) not null,
        Constraint pk_grade_id PRIMARY KEY (grade_id)
    );

    Create Table If Not Exists clearing_house.tbl_clearinghouse_user_roles (
        role_id int not null,
        role_name character varying(255) not null,
        Constraint pk_role_id PRIMARY KEY (role_id)
    );

    Create Table If Not Exists clearing_house.tbl_clearinghouse_users (
        user_id serial not null,
        user_name character varying(255) not null,
        full_name character varying(255) not null default(''),
        password character varying(255) not null,
        email character varying(1024) not null default (''),
        signal_receiver boolean not null default(false),
        role_id int not null default(1),
        data_provider_grade_id int not null default(2),
        is_data_provider boolean not null default(false),
        create_date date not null,
        Constraint pk_user_id PRIMARY KEY (user_id),
        Constraint fk_tbl_user_roles_role_id FOREIGN KEY (role_id)
            References clearing_house.tbl_clearinghouse_user_roles (role_id) MATCH SIMPLE
                ON Update NO Action ON DELETE NO ACTION,
        Constraint fk_tbl_data_provider_grades_grade_id FOREIGN KEY (data_provider_grade_id)
            References clearing_house.tbl_clearinghouse_data_provider_grades (grade_id) MATCH SIMPLE
                ON Update NO Action ON DELETE NO ACTION
    );

    /*********************************************************************************************************************************
    ** Submissions
    **********************************************************************************************************************************/

    Create Table If Not Exists clearing_house.tbl_clearinghouse_submission_states (
        submission_state_id int not null,
        submission_state_name character varying(255) not null,
        CONSTRAINT pk_submission_state_id PRIMARY KEY (submission_state_id)
    );

    Create Table If Not Exists clearing_house.tbl_clearinghouse_submissions
    (
        submission_id serial NOT NULL,
        submission_state_id integer NOT NULL,
        data_types character varying(255),
        upload_user_id integer NOT NULL,
        upload_date Date Not Null default now(),
        upload_content text,
        xml xml,
        status_text text,
        claim_user_id integer,
        claim_date_time date,
        Constraint pk_submission_id PRIMARY KEY (submission_id),
        Constraint fk_tbl_submissions_user_id_user_id FOREIGN KEY (claim_user_id)
            References clearing_house.tbl_clearinghouse_users (user_id) MATCH SIMPLE
            ON UPDATE NO ACTION ON DELETE NO ACTION,
        Constraint fk_tbl_submissions_state_id_state_id FOREIGN KEY (submission_state_id)
            References clearing_house.tbl_clearinghouse_submission_states (submission_state_id) MATCH SIMPLE
            ON UPDATE NO ACTION ON DELETE NO ACTION
    );

    /*********************************************************************************************************************************
    ** XML content tables - intermediate tables using during process
    **********************************************************************************************************************************/

    Create Table If Not Exists clearing_house.tbl_clearinghouse_submission_tables (
        table_id serial not null,
        table_name character varying(255) not null,
        table_name_underscored character varying(255) not null,
        Constraint pk_tbl_clearinghouse_submission_tables Primary Key (table_id)
    );

    Drop Index If Exists clearing_house.idx_tbl_clearinghouse_submission_tables_name1;
    Create Unique Index idx_tbl_clearinghouse_submission_tables_name1
        On clearing_house.tbl_clearinghouse_submission_tables (table_name);

    Drop Index If Exists clearing_house.idx_tbl_clearinghouse_submission_tables_name2;
    Create Unique Index idx_tbl_clearinghouse_submission_tables_name2
        On clearing_house.tbl_clearinghouse_submission_tables (table_name_underscored);

    Create Table If not Exists clearing_house.tbl_clearinghouse_submission_xml_content_tables (
        content_table_id serial not null,
        submission_id int not null,
        table_id int not null,
        record_count int not null,
        Constraint pk_tbl_submission_xml_content_meta_tables_table_id Primary Key (content_table_id),
        Constraint fk_tbl_clearinghouse_submission_xml_content_tables Foreign Key (table_id)
            References clearing_house.tbl_clearinghouse_submission_tables (table_id) Match Simple
            On Update NO ACTION ON DELETE Cascade,
        Constraint fk_tbl_clearinghouse_submission_xml_content_tables_sid Foreign Key (submission_id)
            References clearing_house.tbl_clearinghouse_submissions (submission_id) Match Simple
                On Update NO ACTION ON DELETE Cascade
    );


    Drop Index If Exists clearing_house.fk_idx_tbl_submission_xml_content_tables_table_name;
    Create Unique Index fk_idx_tbl_submission_xml_content_tables_table_name
        On clearing_house.tbl_clearinghouse_submission_xml_content_tables (submission_id, table_id);

    Create Table If Not Exists clearing_house.tbl_clearinghouse_submission_xml_content_columns (
        column_id serial not null,
        submission_id int not null,
        table_id int not null,
        column_name character varying(255) not null,
        column_name_underscored character varying(255) not null,
        data_type character varying(255) not null,
        fk_flag boolean not null,
        fk_table character varying(255) null,
        fk_table_underscored character varying(255) null,
        Constraint pk_tbl_submission_xml_content_columns_column_id Primary Key (column_id),
        Constraint fk_tbl_submission_xml_content_columns_table_id Foreign Key (table_id)
            References clearing_house.tbl_clearinghouse_submission_tables (table_id) Match Simple
            On Update NO ACTION ON DELETE Cascade
    );

    Drop Index If Exists clearing_house.idx_tbl_submission_xml_content_columns_submission_id;
    Create Unique Index idx_tbl_submission_xml_content_columns_submission_id
        On clearing_house.tbl_clearinghouse_submission_xml_content_columns (submission_id, table_id, column_name);

    Create Table If Not Exists clearing_house.tbl_clearinghouse_submission_xml_content_records (
        record_id serial not null,
        submission_id int not null,
        table_id int not null,
        local_db_id int null,
        public_db_id int null,
        Constraint pk_tbl_submission_xml_content_records_record_id Primary Key (record_id),
        Constraint fk_tbl_submission_xml_content_records_table_id Foreign Key (table_id)
            References clearing_house.tbl_clearinghouse_submission_tables (table_id) Match Simple
            On Update NO ACTION ON DELETE Cascade

    );

    Drop Index If Exists clearing_house.idx_tbl_submission_xml_content_records_submission_id;
    Create Unique Index idx_tbl_submission_xml_content_records_submission_id
        On clearing_house.tbl_clearinghouse_submission_xml_content_records (submission_id, table_id, local_db_id);

    Create Table If Not Exists clearing_house.tbl_clearinghouse_submission_xml_content_values (
        value_id serial not null,
        submission_id int not null,
        table_id int not null,
        local_db_id int not null,
        column_id int not null,
        fk_flag boolean null,
        fk_local_db_id int null,
        fk_public_db_id int null,
        value text null,
        Constraint pk_tbl_submission_xml_content_record_values_value_id Primary Key (value_id),
        Constraint fk_tbl_submission_xml_content_meta_record_values_table_id Foreign Key (table_id)
            References clearing_house.tbl_clearinghouse_submission_tables (table_id) Match Simple
            On Update NO ACTION ON DELETE Cascade

    );

    Drop Index If Exists clearing_house.idx_tbl_submission_xml_content_record_values_column_id;
    Create Unique Index idx_tbl_submission_xml_content_record_values_column_id
        On clearing_house.tbl_clearinghouse_submission_xml_content_values (submission_id, table_id, local_db_id, column_id);


    CREATE TABLE  If Not Exists "clearing_house"."tbl_clearinghouse_sead_create_table_log" (
        "create_script" text COLLATE "pg_catalog"."default",
        "drop_script" text COLLATE "pg_catalog"."default"
    );

    CREATE TABLE  If Not Exists "clearing_house"."tbl_clearinghouse_sead_create_view_log" (
        "create_script" text COLLATE "pg_catalog"."default",
        "drop_script" text COLLATE "pg_catalog"."default"
    );

    CREATE TABLE If Not Exists clearing_house.tbl_clearinghouse_submission_tables
    (
        table_id integer NOT NULL DEFAULT nextval('clearing_house.tbl_clearinghouse_submission_tables_table_id_seq'::regclass),
        table_name character varying(255) COLLATE pg_catalog."default" NOT NULL,
        table_name_underscored character varying(255) COLLATE pg_catalog."default" NOT NULL,
        CONSTRAINT pk_tbl_clearinghouse_submission_tables PRIMARY KEY (table_id)
    );

    Drop Index If Exists clearing_house.idx_tbl_clearinghouse_submission_tables_name1;
        CREATE UNIQUE INDEX idx_tbl_clearinghouse_submission_tables_name1
        ON clearing_house.tbl_clearinghouse_submission_tables USING btree
        (table_name COLLATE pg_catalog."default")
        TABLESPACE pg_default;

    Drop Index If Exists clearing_house.idx_tbl_clearinghouse_submission_tables_name2;
        CREATE UNIQUE INDEX idx_tbl_clearinghouse_submission_tables_name2
        ON clearing_house.tbl_clearinghouse_submission_tables USING btree
        (table_name_underscored COLLATE pg_catalog."default")
        TABLESPACE pg_default;

    Create Table If Not Exists clearing_house.tbl_clearinghouse_accepted_submissions
    (
        accepted_submission_id serial NOT NULL,
        process_state_id bool NOT NULL,
        submission_id int,
        upload_file text,
        accept_user_id integer,
        Constraint pk_tbl_clearinghouse_accepted_submissions PRIMARY KEY (accepted_submission_id)
    );

    Create Table If Not Exists clearing_house.tbl_clearinghouse_reject_entity_types
    (
        entity_type_id int NOT NULL,
        table_id int NULL,
        entity_type character varying(255) NOT NULL,
        Constraint pk_tbl_clearinghouse_reject_entity_types PRIMARY KEY (entity_type_id)
    );

    Drop Index If Exists clearing_house.fk_clearinghouse_reject_entity_types;
    Create Index fk_clearinghouse_reject_entity_types On clearing_house.tbl_clearinghouse_reject_entity_types (table_id);

    Create Table If Not Exists clearing_house.tbl_clearinghouse_submission_rejects
    (
        submission_reject_id serial NOT NULL,
        submission_id int NOT NULL,
        site_id int NOT NULL default(0),
        entity_type_id int NOT NULL,
        reject_scope_id int NOT NULL, /* 0, 1=specific, 2=General */
        reject_description text NULL,
        Constraint pk_tbl_clearinghouse_submission_rejects PRIMARY KEY (submission_reject_id),
        Constraint fk_tbl_clearinghouse_submission_rejects_submission_id Foreign Key (submission_id)
            References clearing_house.tbl_clearinghouse_submissions (submission_id) Match Simple
            On Update NO ACTION ON DELETE Cascade
    );

    Drop Index If Exists clearing_house.fk_clearinghouse_submission_rejects;
    Create Index fk_clearinghouse_submission_rejects On clearing_house.tbl_clearinghouse_submission_rejects (submission_id);

    Create Table If Not Exists clearing_house.tbl_clearinghouse_submission_reject_entities
    (
        reject_entity_id serial NOT NULL,
        submission_reject_id int NOT NULL,
        local_db_id int NOT NULL,
        Constraint pk_tbl_clearinghouse_submission_reject_entities PRIMARY KEY (reject_entity_id),
        Constraint fk_tbl_clearinghouse_submission_reject_entities Foreign Key (submission_reject_id)
            References clearing_house.tbl_clearinghouse_submission_rejects (submission_reject_id) Match Simple
            On Update NO ACTION ON DELETE Cascade
    );

    Drop Index If Exists clearing_house.fk_clearinghouse_submission_reject_entities_submission;
    Create Index fk_clearinghouse_submission_reject_entities_submission On clearing_house.tbl_clearinghouse_submission_reject_entities (submission_reject_id);

    Drop Index If Exists clearing_house.fk_clearinghouse_submission_reject_entities_local_db_id;
    Create Index fk_clearinghouse_submission_reject_entities_local_db_id On clearing_house.tbl_clearinghouse_submission_reject_entities (local_db_id);

    Create Table If Not Exists clearing_house.tbl_clearinghouse_reports
    (
        report_id int NOT NULL,
        report_name character varying(255),
        report_procedure text not null,
        Constraint pk_tbl_clearinghouse_reports PRIMARY KEY (report_id)
    );

    Create Table If Not Exists clearing_house.tbl_clearinghouse_sead_unknown_column_log (
        column_log_id serial not null,
        submission_id int,
        table_name text,
        column_name text,
        column_type text,
        alter_sql text,
        Constraint pk_tbl_clearinghouse_sead_unknown_column_log PRIMARY KEY (column_log_id)
    );

End $$ Language plpgsql;

/*****************************************************************************************************************************
**	Function	fn_truncate_all_entity_tables
**	Who			Roger Mähler
**	When		2018-03-25
**	What		Truncates all clearinghouse entity tables and resets sequences
**  Note        NOTE! This Function clears ALL entities in CH tables!
**	Uses
**	Revisions
******************************************************************************************************************************/
-- Select clearing_house.fn_truncate_all_entity_tables()
Create Or Replace Function clearing_house.fn_truncate_all_entity_tables()
Returns void As $$
    Declare x record;
    Declare command text;
    Declare item_count int;
Begin

    -- Raise 'This error raise must be removed before this function will run';

	For x In (
        Select t.*
        From clearing_house.tbl_clearinghouse_submission_tables t
	) Loop

        command = 'select count(*) from clearing_house.' || x.table_name_underscored || ';';

        Raise Notice '%: %', command, item_count;

        Begin
            Execute command Into item_count;
            If item_count > 0 Then
                command = 'TRUNCATE clearing_house.' || x.table_name_underscored || ' RESTART IDENTITY;';
                Execute command;
            End If;
       Exception
            When undefined_table Then
                Raise Notice 'Missing: %', x.table_name_underscored;
                -- Do nothing, and loop to try the UPDATE again.
       End;

	Truncate Table clearing_house.tbl_clearinghouse_submission_xml_content_values Restart Identity Cascade;
	Truncate Table clearing_house.tbl_clearinghouse_submission_xml_content_columns Restart Identity Cascade;
	Truncate Table clearing_house.tbl_clearinghouse_submission_xml_content_records Restart Identity Cascade;
	Truncate Table clearing_house.tbl_clearinghouse_submission_xml_content_tables Restart Identity Cascade;
    Truncate Table clearing_house.tbl_clearinghouse_submissions Restart Identity Cascade;
    -- Truncate Table clearing_house.tbl_clearinghouse_xml_temp Restart Identity Cascade;

	End Loop;
	End
$$ Language plpgsql;
/*********************************************************************************************************************************
**  Function    populate_clearinghouse_model
**  When        2017-11-06
**  What        Adds data to DB clearing_house specific schema objects
**  Who         Roger Mähler
**  Note
**  Uses
**  Used By     Clearing House server installation. DBA.
**  Revisions
**********************************************************************************************************************************/
-- Select clearing_house.fn_dba_populate_clearing_house_db_model();
Create Or Replace procedure clearing_house.populate_clearinghouse_model() As $$
Begin

    If (Select Count(*) From clearing_house.tbl_clearinghouse_settings) = 0 Then

        Insert Into clearing_house.tbl_clearinghouse_settings (setting_group, setting_key, setting_value, setting_datatype)
            Values
                ('logger', 'folder', '/tmp/', 'string'),
                ('', 'max_execution_time', '120', 'numeric'),
                ('mailer', 'smtp-server', 'mail.acc.umu.se', 'string'),
                ('mailer', 'reply-address', 'noreply@sead.se', 'string'),
                ('mailer', 'sender-name', 'SEAD Clearing House', 'string'),
                ('mailer', 'smtp-auth', 'false', 'bool'),
                ('mailer', 'smtp-username', '', 'string'),
                ('mailer', 'smtp-password', '', 'string'),
                ('signal-templates', 'reject-subject', 'SEAD Clearing House: submission has been rejected', 'string'),
                ('signal-templates', 'reject-body',
'
Your submission to SEAD Clearing House has been rejected!

Reject causes:

#REJECT-CAUSES#

This is an auto-generated mail from the SEAD Clearing House system

', 'string'),

                ('signal-templates', 'reject-cause',
'

Entity type: #ENTITY-TYPE#
Error scope: #ERROR-SCOPE#
Entities: #ENTITY-ID-LIST#
Note:  #ERROR-DESCRIPTION#

--------------------------------------------------------------------

', 'string'),

                ('signal-templates', 'accept-subject', 'SEAD Clearing House: submission has been accepted', 'string'),
                ('signal-templates', 'accept-body',
'

Your submission to SEAD Clearing House has been accepted!

This is an auto-generated mail from the SEAD Clearing House system

', 'string'),

                ('signal-templates', 'reclaim-subject', 'SEAD Clearing House notfication: Submission #SUBMISSION-ID# has been transfered to pending', 'string'),
                ('signal-templates', 'reclaim-body', '

Status of submission #SUBMISSION-ID# has been reset to pending due to inactivity.

A submission is automatically reset to pending status when #DAYS-UNTIL-RECLAIM# days have passed since the submission
was claimed for review, and if no activity during has been registered during last #DAYS-WITHOUT-ACTIVITY# days.

This is an auto-generated mail from the SEAD Clearing House system.

', 'string'),
                ('signal-templates', 'reminder-subject', 'SEAD Clearing House reminder: Submission #SUBMISSION-ID#', 'string'),
                ('signal-templates', 'reminder-body', '

Status of submission #SUBMISSION-ID# has been reset to pending due to inactivity.

A reminder is automatically send when #DAYS-UNTIL-REMINDER# have passed since the submission
was claimed for review.

This is an auto-generated mail from the SEAD Clearing House system.

', 'string'),
                ('reminder', 'days_until_first_reminder', '14', 'numeric'),
                ('reminder', 'days_since_claimed_until_transfer_back_to_pending', '28', 'numeric'),
                ('reminder', 'days_without_activity_until_transfer_back_to_pending', '14', 'numeric');
    End If;

    insert into clearing_house.tbl_clearinghouse_info_references (info_reference_type, display_name, href)
        values
            ('link', 'SEAD overview article',  'http://bugscep.com/phil/publications/Buckland2010_jns.pdf'),
            ('link', 'Popular science description of SEAD aims',  'http://bugscep.com/phil/publications/buckland2011_international_innovation.pdf')
        on conflict do nothing;

    insert into clearing_house.tbl_clearinghouse_use_cases (use_case_id, use_case_name, entity_type_id)
        values  (0, 'General', 0),
                (1, 'Login', 1),
                (2, 'Logout', 1),
                (3, 'Upload submission', 2),
                (4, 'Accept submission', 2),
                (5, 'Reject submission', 2),
                (6, 'Open submission', 2),
                (7, 'Process submission', 2),
                (8, 'Transfer submission', 2),
                (9, 'Add reject cause', 2),
                (10, 'Delete reject cause', 2),
                (11, 'Claim submission', 2),
                (12, 'Unclaim submission', 2),
                (13, 'Execute report', 2),
                (20, 'Add user', 1),
                (21, 'Change user', 1),
                (22, 'Send reminder', 2),
                (23, 'Reclaim submission', 2),
                (24, 'Nag', 0)
        on conflict (use_case_id)
            do update
                set use_case_name = excluded.use_case_name,
                    entity_type_id = excluded.entity_type_id;

    insert into clearing_house.tbl_clearinghouse_data_provider_grades (grade_id, description)
        values (0, 'n/a'), (1, 'Normal'), (2, 'Good'), (3, 'Excellent')
        on conflict (grade_id)
            do update
                set description = excluded.description;

    insert into clearing_house.tbl_clearinghouse_user_roles (role_id, role_name)
        values (0, 'Undefined'),
                (1, 'Reader'),
                (2, 'Normal'),
                (3, 'Administrator'),
                (4, 'Data Provider')
        on conflict (role_id)
            do update
                set role_name = excluded.role_name;

    Insert Into clearing_house.tbl_clearinghouse_users (user_name, password, full_name, role_id, data_provider_grade_id, create_date, email, signal_receiver)
        Values ('test_reader', '$2y$10$/u3RCeK8Q.2s75UsZmvQ4.4TOxvLNKH8EoH4k6NYYtkAMavjP.dry', 'Test Reader', 1, 0, '2013-10-08', 'roger.mahler@umu.se', false),
                ('test_normal', '$2y$10$/u3RCeK8Q.2s75UsZmvQ4.4TOxvLNKH8EoH4k6NYYtkAMavjP.dry', 'Test Normal', 2, 0, '2013-10-08', 'roger.mahler@umu.se', false),
                ('test_admin', '$2y$10$/u3RCeK8Q.2s75UsZmvQ4.4TOxvLNKH8EoH4k6NYYtkAMavjP.dry', 'Test Administrator', 3, 0, '2013-10-08', 'roger.mahler@umu.se', true),
                ('test_provider', '$2y$10$/u3RCeK8Q.2s75UsZmvQ4.4TOxvLNKH8EoH4k6NYYtkAMavjP.dry', 'Test Provider', 3, 3, '2013-10-08', 'roger.mahler@umu.se', true),
                ('phil_admin', '$2y$10$/u3RCeK8Q.2s75UsZmvQ4.4TOxvLNKH8EoH4k6NYYtkAMavjP.dry', 'Phil Buckland', 3, 3, '2013-10-08', 'phil.buckland@umu.se', true),
                ('mattias_admin', '$2y$10$/u3RCeK8Q.2s75UsZmvQ4.4TOxvLNKH8EoH4k6NYYtkAMavjP.dry', 'Mattias Sjölander', 3, 3, '2013-10-08', 'mattias.sjolander@umu.se', true)
        on conflict do nothing;

    with sead_tables as (
        Select distinct table_name
        From clearing_house.fn_dba_get_sead_public_db_schema('public', 'sead_master')
    ) insert into clearing_house.tbl_clearinghouse_submission_tables (table_name, table_name_underscored)
        select replace(initcap(replace(table_name, '_', ' ')), ' ', '') , table_name
        from sead_tables
        where table_name Like 'tbl_%'
      on conflict (table_name) do nothing;

    insert into clearing_house.tbl_clearinghouse_submission_states (submission_state_id, submission_state_name)
        values	(0, 'Undefined'),
                (1, 'New'),
                (2, 'Pending'),
                (3, 'In progress'),
                (4, 'Accepted'),
                (5, 'Rejected'),
                (9, 'Error')
        on conflict do nothing;

    If (Select Count(*) From clearing_house.tbl_clearinghouse_reject_entity_types) = 0 Then

        Insert Into clearing_house.tbl_clearinghouse_reject_entity_types (entity_type_id, table_id, entity_type)

            Select 0,  0, 'Not specified'
			Union
            Select row_number() over (ORDER BY table_name),  table_id, left(substring(table_name,4),Length(table_name)-4)
            From clearing_house.tbl_clearinghouse_submission_tables
            Where table_name Like 'Tbl%s'
            Order by 1;

        /* Komplettera med nya */
        Insert Into clearing_house.tbl_clearinghouse_reject_entity_types (entity_type_id, table_id, entity_type)

            Select (Select Max(entity_type_id) From clearing_house.tbl_clearinghouse_reject_entity_types) + row_number() over (ORDER BY table_name),  t.table_id, left(substring(table_name,4),Length(table_name)-3)
            From clearing_house.tbl_clearinghouse_submission_tables t
			Left Join clearing_house.tbl_clearinghouse_reject_entity_types x
			  On x.table_id = t.table_id
            Where x.table_id Is Null
            Order by 1;

        /* Fixa beskrivningstext */
        Update clearing_house.tbl_clearinghouse_reject_entity_types as x
			set entity_type = replace(trim(replace(regexp_replace(t.table_name, E'([A-Z])', E'\_\\1','g'), '_', ' ')), 'Tbl ', '')
        From clearing_house.tbl_clearinghouse_submission_tables t
        Where t.table_id = x.table_id
          And replace(trim(replace(regexp_replace(t.table_name, E'([A-Z])', E'\_\\1','g'), '_', ' ')), 'Tbl ', '') <> x.entity_type;

    End If;

    insert into clearing_house.tbl_clearinghouse_reports (report_id, report_name, report_procedure)
        values  ( 1, 'Locations', 'Select * From clearing_house.fn_clearinghouse_report_locations(?)'),
                ( 2, 'Bibliography entries', 'Select * From clearing_house.fn_clearinghouse_report_bibliographic_entries(?)'),
                ( 3, 'Data sets', 'Select * From clearing_house.fn_clearinghouse_report_datasets(?)'),
                ( 4, 'Ecological reference data - Taxonomic order', 'Select * From clearing_house.fn_clearinghouse_report_taxonomic_order(?)'),
                ( 5, 'Taxonomic tree (master)', 'Select * From clearing_house.fn_clearinghouse_report_taxa_tree_master(?)'),
                ( 6, 'Ecological reference data - Taxonomic tree (other)', 'Select * From clearing_house.fn_clearinghouse_report_taxa_other_lists(?)'),
                ( 7, 'Ecological reference data - Taxonomic RGB codes', 'Select * From clearing_house.fn_clearinghouse_report_taxa_rdb(?)'),
                ( 8, 'Ecological reference data - Taxonomic eco-codes', 'Select * From clearing_house.fn_clearinghouse_report_taxa_ecocodes(?)'),
                ( 9, 'Ecological reference data - Taxonomic seasonanlity', 'Select * From clearing_house.fn_clearinghouse_report_taxa_seasonality(?)'),
                (11, 'Relative ages', 'Select * From clearing_house.fn_clearinghouse_report_relative_ages(?)'),
                (12, 'Methods', 'Select * From clearing_house.fn_clearinghouse_report_methods(?)'),
                (13, 'Feature types', 'Select * From clearing_house.fn_clearinghouse_report_feature_types(?)'),
                (14, 'Sample group descriptions', 'Select * From clearing_house.fn_clearinghouse_report_sample_group_descriptions(?)'),
                (15, 'Sample group dimensions', 'Select * From clearing_house.fn_clearinghouse_report_sample_group_dimensions(?)'),
                (16, 'Sample dimensions', 'Select * From clearing_house.fn_clearinghouse_report_sample_dimensions(?)'),
                (17, 'Sample descriptions', 'Select * From clearing_house.fn_clearinghouse_report_sample_descriptions(?)'),
                -- (18, 'Ceramic values', 'Select * From clearing_house.fn_clearinghouse_review_ceramic_values_crosstab(?)')
                (18, 'Analysis values', 'Select * From clearing_house.fn_clearinghouse_review_generic_analysis_lookup_values_crosstab(?, null)')
    on conflict (report_id)
        do update
            set report_name = excluded.report_name,
                report_procedure = excluded.report_procedure;

end $$ language plpgsql;
/*****************************************************************************************************************************
**	Type	clearing_house.transport_type
******************************************************************************************************************************/

do $$
begin
    if not exists (
        select 1
        from pg_type
        join pg_namespace
          on pg_type.typnamespace = pg_namespace.oid
        where typname = 'transport_type'
          and nspname = 'clearing_house'
    ) then
        create domain clearing_house.transport_type char
            check (value is null or value in ('C', 'U', 'D')) default null null;
    end if;
end $$ language plpgsql;

/*****************************************************************************************************************************
**	Function	fn_rdb_schema_script_table
**	Who			Roger Mähler
**	When		2013-10-17
**	What		Create type string based on schema type fields.
**	Revisions
******************************************************************************************************************************/
-- Select clearing_house.fn_create_schema_type_string('character varying', 255, null, null, 'YES')
Create Or Replace Function clearing_house.fn_create_schema_type_string(
	data_type character varying(255),
	character_maximum_length int,
	numeric_precision int,
	numeric_scale int,
	is_nullable character varying(10)
) Returns text As $$
	Declare type_string text;
Begin
	type_string :=  data_type
		||	Case When data_type = 'character varying' And Coalesce(character_maximum_length, 0) > 0
                    Then '(' || Coalesce(character_maximum_length::text, '255') || ')'
				 When data_type = 'numeric' Then
					Case When numeric_precision Is Null And numeric_scale Is Null Then  ''
						 When numeric_scale Is Null Then  '(' || numeric_precision::text || ')'
						 Else '(' || numeric_precision::text || ', ' || numeric_scale::text || ')'
					End
				 Else '' End || ' '|| Case When Coalesce(is_nullable,'') = 'YES' Then 'null' Else 'not null' End;
	return type_string;

End $$ Language plpgsql;

/*****************************************************************************************************************************
**	Function	fn_script_public_db_entity_table
**	Who			Roger Mähler
**	When		2018-06-25
**	What		Creates new CHDB tables based on SEAD information_schema.catalog
**					- All columns in SEAD catalog is included, and using the same data_types and null attribute
**					- CHDB specific columns submission_id and source_id (LDB or PDB) is added
**					- XML attribute "id" is mapped to CHDB field "local_db_id"
**					- XML attribute "cloned_id" is mapped to CHDB field "public_db_id"
**					- PK in new table is submission_id + source_id + "PK:s in Local DB'
**  Uses
**  Used By
**	Revisions   2018-06-25 / removed loop
**	TODO		Add keys on foreign indexes to improve performance.
******************************************************************************************************************************/
-- Select clearing_house.fn_script_public_db_entity_table('public', 'clearing_house', 'tbl_sites')
Create Or Replace Function clearing_house.fn_script_public_db_entity_table(p_source_schema character varying(255), p_target_schema character varying(255), p_table_name character varying(255)) Returns text As $$
	Declare sql_stmt text;
	Declare data_columns text;
	Declare pk_columns text;
Begin

    Select string_agg(column_name || ' ' || clearing_house.fn_create_schema_type_string(data_type, character_maximum_length, numeric_precision, numeric_scale, is_nullable), E',\n        ' ORDER BY ordinal_position ASC),
           string_agg(Case When is_pk = 'YES' Then column_name Else Null End, E', ' ORDER BY ordinal_position ASC)
    Into Strict data_columns, pk_columns
    From clearing_house.fn_dba_get_sead_public_db_schema('public', 'sead_master') s
    Where s.table_schema = p_source_schema
      And s.table_name = p_table_name;

    -- ASSERT NOT pk_columns IS NULL;

	sql_stmt = format('Create Table %I.%I (

        %s,

        submission_id int not null,
        source_id int not null,
        local_db_id int not null,
        public_db_id int null,

        transport_type clearing_house.transport_type,
        transport_date timestamp with time zone,
        transport_id int,

        Constraint pk_%s Primary Key (submission_id, source_id, %s)

	);
    Create Index idx_%s_submission_id_public_id On %I.%I (submission_id, public_db_id);',
        p_target_schema, p_table_name, data_columns, p_table_name, pk_columns,
        p_table_name, p_target_schema, p_table_name);

	Return sql_stmt;

End $$ Language plpgsql;

/*****************************************************************************************************************************
**	Function	fn_create_public_db_entity_tables
**	Who			Roger Mähler
**	When		2013-10-14
**	What		Creates a local copy in schema clearing_house of all public db entity tables
**  Note
**  Uses
**  Used By
**	Revisions
******************************************************************************************************************************/
-- Select clearing_house.fn_create_public_db_entity_tables('clearing_house')
-- Select * From clearing_house.tbl_clearinghouse_sead_create_table_log
Create Or Replace Function clearing_house.fn_create_public_db_entity_tables(
    target_schema character varying(255),
    p_only_drop BOOLEAN = FALSE,
    p_dry_run BOOLEAN = TRUE
) Returns void As $$
	Declare x RECORD;
	Declare create_script text;
	Declare drop_script text;
Begin
    If Not p_dry_run Then
        Create Table If Not Exists clearing_house.tbl_clearinghouse_sead_create_table_log (
            create_log_id SERIAL PRIMARY KEY,
            create_script text,
            drop_script text,
            date_updated timestamp with time zone DEFAULT now()
        );
        Delete From clearing_house.tbl_clearinghouse_sead_create_table_log;
    End If;
	For x In (
		Select distinct table_schema As source_schema, table_name
		From clearing_house.fn_dba_get_sead_public_db_schema('public', 'sead_master')
	)
	Loop
        drop_script := format('Drop Table If Exists %I.%I CASCADE;', target_schema, x.table_name);
        create_script := clearing_house.fn_script_public_db_entity_table(x.source_schema, target_schema, x.table_name);
        If p_dry_run Then
            Raise Notice '%', drop_script;
            Raise Notice '%', create_script;
        Else
            Execute drop_script;
            If Not p_only_drop Then
                Execute create_script;
            End If;
            Insert Into clearing_house.tbl_clearinghouse_sead_create_table_log (create_script, drop_script) Values (create_script, drop_script);
        End If;
	End Loop;
End $$ Language plpgsql;

/*****************************************************************************************************************************
**	Function	fn_create_local_public_primary_key_view
**	Who			Roger Mähler
**	When		2018-06-15
**	What		Fast lookup of public_db_id given submission_id, local_db_id to public_db_id
**  Note        Is a MTERIALIZED view that MUST BE UPDATED!
**  Uses
**  Used By     Transfer CH-data to SEAD module
**	Revisions
******************************************************************************************************************************/

CREATE OR REPLACE FUNCTION clearing_house.fn_create_local_to_public_id_view() RETURNS VOID AS $$
DECLARE v_sql text;
BEGIN

	SELECT string_agg(' SELECT submission_id, ''' || table_name || ''' as table_name, local_db_id, public_db_id from clearing_house.' || table_name || '', E'  \nUNION ')
		INTO STRICT v_sql
	FROM clearing_house.fn_dba_get_sead_public_db_schema('public', 'sead_master')
	WHERE table_name LIKE 'tbl%'
	  AND is_pk = 'YES';

	v_sql = E'
		DROP VIEW IF EXISTS clearing_house.view_local_to_public_id;
		CREATE MATERIALIZED VIEW clearing_house.view_local_to_public_id AS \n' || v_sql	|| ';
		DROP INDEX IF EXISTS idx_view_local_to_public_id;
		CREATE INDEX idx_view_local_to_public_id ON clearing_house.view_local_to_public_id (submission_id, table_name, local_db_id);';

	EXECUTE v_sql;

END;
$$ LANGUAGE plpgsql;

-- SELECT clearing_house.fn_create_local_to_public_id_view();
-- CREATE OR REPLACE FUNCTION clearing_house.fn_local_to_public_id(int,varchar,int) RETURNS INT
-- 	AS 'SELECT public_db_id FROM clearing_house.view_local_to_public_id WHERE submission_id = $1 and table_name = $2 and local_db_id = $3; '
-- 	LANGUAGE SQL STABLE RETURNS NULL ON NULL INPUT;

-- REFRESH MATERIALIZED VIEW clearing_house.view_local_to_public_id;

/*****************************************************************************************************************************
**	Function	fn_add_new_public_db_columns
**	Who			Roger Mähler
**	When		2013-10-14
**	What		Adds missing columns found in public db to local entity table
**  Note
**  Uses
**  Used By
**	Revisions
******************************************************************************************************************************/
-- Select clearing_house.fn_add_new_public_db_columns(2, 'tbl_datasets')
Create Or Replace Function clearing_house.fn_add_new_public_db_columns(
    p_submission_id int, p_table_name character varying(255)
) Returns void As $$

	Declare xml_columns character varying(255)[];
	Declare sql text;
	Declare x RECORD;

Begin
	xml_columns := clearing_house.fn_get_submission_table_column_names(p_submission_id, p_table_name);
	If array_length(xml_columns, 1) = 0 Then
		Raise Exception 'Fatal error. Table % has unknown fields.', p_table_name;
		Return;
	End If;

	If Not clearing_house.fn_table_exists(p_table_name) Then
        sql := clearing_house.fn_script_public_db_entity_table('public', 'clearing_house', p_table_name);
		Raise Notice '%', sql;
--		Execute sql;
		Raise Exception 'Fatal error. Table % does not exist.', p_table_name;
	End If;

	For x In (
		Select Distinct t.table_name_underscored, c.column_name_underscored, c.data_type
		From clearing_house.tbl_clearinghouse_submission_tables t
		Join clearing_house.tbl_clearinghouse_submission_xml_content_columns c
		  On c.table_id = t.table_id
		Left Join INFORMATION_SCHEMA.columns ic
		  On ic.table_schema = 'clearing_house'
		 And ic.table_name = t.table_name_underscored
		 And ic.column_name = c.column_name_underscored
		Where c.submission_id = p_submission_id
		  And t.table_name_underscored = p_table_name
		  And c.column_name_underscored <> 'cloned_id'
		  And ic.table_name Is Null
	) Loop

        -- Break instead of automatic INSERT
		Raise Exception 'Fatal error. Unknown column found in XML. Target table %, column %s does not exist.',  x.table_name_underscored,  x.column_name_underscored;

		sql := format('Alter Table clearing_house.%I Add Column %I %s null;',
            p_table_name, x.column_name_underscored, clearing_house.fn_java_type_to_PostgreSQL(x.data_type)
        );

		Execute sql;

		Raise Notice 'Added new column: % % % [%]', x.table_name_underscored,  x.column_name_underscored , clearing_house.fn_java_type_to_PostgreSQL(x.data_type), sql;

        Insert Into clearing_house.tbl_clearinghouse_sead_unknown_column_log (submission_id, table_name, column_name, column_type, alter_sql)
            Values (p_submission_id, x.table_name_underscored, x.column_name_underscored, clearing_house.fn_java_type_to_PostgreSQL(x.data_type), sql);

	End Loop;

End $$ Language plpgsql;

/*****************************************************************************************************************************
**	Function	fn_script_local_union_public_entity_view
**	Who			Roger Mähler
**	When		2013-10-14
**	What		Creates union views of local and public data
**  Uses
**  Used By
**	Revisions
******************************************************************************************************************************/
-- Select clearing_house.fn_script_local_union_public_entity_view('clearing_house', 'clearing_house', 'public', 'tbl_dating_uncertainty')
Create Or Replace Function clearing_house.fn_script_local_union_public_entity_view(
    target_schema character varying(255),
    local_schema character varying(255),
    public_schema character varying(255),
    table_name character varying(255)
) Returns text As $$
	#variable_conflict use_variable
	Declare sql_template text;
	Declare sql text;
	Declare column_list text;
	Declare pk_field text;
Begin

	sql_template =
'
Create Or Replace View #TARGET-SCHEMA#.#VIEW-NAME# As
    /*
    **	Function #VIEW-NAME#
    **	Who      THIS VIEW IS AUTO-GENERATED BY fn_create_local_union_public_entity_views / Roger Mähler
    **	When     #DATE#
    **	What     Returns union of local and public versions of #TABLE-NAME#
    **  Uses     clearing_house.fn_dba_get_sead_public_db_schema
    **	Note     Please re-run fn_create_local_union_public_entity_views whenever public schema is changed
    **  Used By  SEAD Clearing House
    **/

    Select #COLUMN-LIST#, submission_id, source_id, local_db_id as merged_db_id, local_db_id, public_db_id
    From #LOCAL-SCHEMA#.#TABLE-NAME#
    Union
    Select #COLUMN-LIST#, 0 As submission_id, 2 As source_id, #PK-COLUMN# as merged_db_id, 0 As local_db_id, #PK-COLUMN# As public_db_id
    From #PUBLIC-SCHEMA#.#TABLE-NAME#
;';

	Select array_to_string(array_agg(s.column_name::text Order By s.ordinal_position), ',') Into column_list
	From clearing_house.fn_dba_get_sead_public_db_schema('public', 'sead_master') s
	Join information_schema.columns c /* Column must exist in public and local schema */
	  On c.table_schema = local_schema
	 And c.table_name = table_name
	 And c.column_name = s.column_name
	Where s.table_schema = public_schema
	  And s.table_name = table_name;

	Select column_name Into pk_field
	From clearing_house.fn_dba_get_sead_public_db_schema('public', 'sead_master') s
	Where s.table_schema = public_schema
	  And s.table_name = table_name
	  And s.is_pk = 'YES';

	sql := sql_template;
	sql := replace(sql, '#DATE#', to_char(now(), 'YYYY-MM-DD HH24:MI:SS'));
	sql := replace(sql, '#COLUMN-LIST#', column_list);
	sql := replace(sql, '#PK-COLUMN#', pk_field);
	sql := replace(sql, '#TARGET-SCHEMA#', target_schema);
	sql := replace(sql, '#LOCAL-SCHEMA#', local_schema);
	sql := replace(sql, '#PUBLIC-SCHEMA#', public_schema);
	sql := replace(sql, '#VIEW-NAME#', replace(table_name, 'tbl_', 'view_'));
	sql := replace(sql, '#TABLE-NAME#', table_name);

	Return sql;

End $$ Language plpgsql;

/*****************************************************************************************************************************
**	Function	fn_create_local_union_public_entity_views
**	Who			Roger Mähler
**	When		2013-10-14
**	What		Creates "union-views" of local and public entity tables
**  Note
**  Todo        Option for total recreate - now existing views are untouched
**  Uses
**  Used By
**	Revisions
******************************************************************************************************************************/
-- Select clearing_house.fn_create_local_union_public_entity_views('clearing_house', 'clearing_house', FALSE, TRUE)
-- Select * From clearing_house.tbl_clearinghouse_sead_create_view_log
-- Drop Function clearing_house.fn_create_local_union_public_entity_views(character varying(255), character varying(255), BOOLEAN, BOOLEAN);
Create Or Replace Function clearing_house.fn_create_local_union_public_entity_views(
    target_schema character varying(255),
    local_schema character varying(255),
    p_only_drop BOOLEAN = FALSE,
    p_dry_run BOOLEAN = TRUE
)
Returns void As $$
	Declare v_row RECORD;
	Declare drop_script text;
	Declare create_script text;
Begin

	Create Table If Not Exists clearing_house.tbl_clearinghouse_sead_create_view_log (create_script text, drop_script text);

	For v_row In (
        Select distinct table_schema As public_schema, table_name, replace(table_name, 'tbl_', 'view_') As view_name
        From clearing_house.fn_dba_get_sead_public_db_schema('public', 'sead_master')
        Where is_pk = 'YES' -- /* Måste finnas PK */
          And table_name Like 'tbl_%'
	) Loop

		drop_script = format('Drop View If Exists %I.%I CASCADE;', target_schema, v_row.view_name);
		create_script := clearing_house.fn_script_local_union_public_entity_view(target_schema, local_schema, v_row.public_schema, v_row.table_name);

        Insert Into clearing_house.tbl_clearinghouse_sead_create_view_log (create_script, drop_script) Values (create_script, drop_script);

        If p_dry_run Then
            Raise Notice '%', drop_script;
            Raise Notice '%', create_script;
        Else
            Execute drop_script;
            If Not p_only_drop Then
                Execute create_script;
            End If;
        End If;

	End Loop;

End $$ Language plpgsql;
/*****************************************************************************************************************************
**	Function	fn_generate_foreign_key_indexes
**	Who			Roger Mähler
**	When		2013-10-14
**	What		Generates DDL create index statement if column (via name matching) is FK in public DB and lacks index.
**  Note
**  Uses
**  Used By
**	Revisions
******************************************************************************************************************************/

Create Or Replace Function clearing_house.fn_generate_foreign_key_indexes()
Returns void As $$
Declare x RECORD;
Begin
	For x In (

        Select 'Create Index idx_' || target_constraint_name || ' On clearing_house.' || target_table || ' (' || target_colname || ');' as create_script,
               'Drop Index If Exists clearing_house.idx_' || target_constraint_name || ';' as drop_script
        From (
            select	(select nspname from pg_namespace where oid=m.relnamespace)																as target_ns,
                    m.relname																												as target_table,
                    (select a.attname from pg_attribute a where a.attrelid = m.oid and a.attnum = o.conkey[1] and a.attisdropped = false)	as target_colname,
                    o.conname																												as target_constraint_name,
                    (select nspname from pg_namespace where oid=f.relnamespace)																as foreign_ns,
                    f.relname																												as foreign_table,
                    (select a.attname from pg_attribute a where a.attrelid = f.oid and a.attnum = o.confkey[1] and a.attisdropped = false)	as foreign_colname
            from pg_constraint o
            left join pg_class c
              on c.oid = o.conrelid
            left join pg_class f
              on f.oid = o.confrelid
            left join pg_class m
              on m.oid = o.conrelid
            where o.contype = 'f'
              and o.conrelid in (select oid from pg_class c where c.relkind = 'r')
            order by 2
        ) as x
        Left Join pg_indexes i
          On i.schemaname = 'clearing_house'
         And i.tablename =  target_table
         And i.indexname =  'idx_' || target_constraint_name
        Where target_ns = 'public'
          And i.indexname is null
    ) Loop
        Raise Notice '%', x.drop_script;
        Raise Notice '%', x.create_script;

        Execute x.drop_script;
        Execute x.create_script;
    End Loop;

End $$ Language plpgsql;

/*****************************************************************************************************************************
**	Function	fn_create_clearinghouse_public_db_model
**	Who			Roger Mähler
**	When		2017-11-16
**	What		Calls functions above to create a CH version of public entity tables and viewes that merges
**              local and public entity tables
**  Uses
**  Used By
**	Revisions
******************************************************************************************************************************/

Create Or Replace Procedure clearing_house.create_public_model(
    p_only_drop BOOLEAN = FALSE,
    p_dry_run BOOLEAN = TRUE
) As $$
Begin

    Perform clearing_house.fn_create_public_db_entity_tables('clearing_house', p_only_drop, p_dry_run);
    Perform clearing_house.fn_generate_foreign_key_indexes();
    Perform clearing_house.fn_create_local_union_public_entity_views('clearing_house', 'clearing_house', p_only_drop, p_dry_run);

End $$ Language plpgsql;
call clearing_house.create_clearinghouse_model(false);
call clearing_house.populate_clearinghouse_model();
call clearing_house.create_public_model(false, false);
/*****************************************************************************************************************************
**	Function	fn_delete_submission
**	Who			Roger Mähler
**	When		2018-07-03
**	What		Completely removes a submission
**	Uses
**	Used By
**	Revisions
******************************************************************************************************************************/
-- Select clearing_house.fn_delete_submission(4)

Create Or Replace Function clearing_house.fn_delete_submission(p_submission_id int, p_clear_header boolean=FALSE, p_clear_exploded boolean=TRUE)
Returns void As $$
    Declare v_table_name_underscored character varying;
Begin

    If p_clear_exploded Then
        Delete From clearing_house.tbl_clearinghouse_submission_xml_content_values Where submission_id = p_submission_id;
        Delete From clearing_house.tbl_clearinghouse_submission_xml_content_columns Where submission_id = p_submission_id;
        Delete From clearing_house.tbl_clearinghouse_submission_xml_content_records Where submission_id = p_submission_id;
        Delete From clearing_house.tbl_clearinghouse_submission_xml_content_tables Where submission_id = p_submission_id;
    End If;

    For v_table_name_underscored in (
        Select table_name_underscored
        From clearing_house.tbl_clearinghouse_submission_tables
    ) Loop
        -- Raise Notice 'Table %...', v_table_name_underscored;
        Execute format('Delete From clearing_house.%s Where submission_id = %s;', v_table_name_underscored, p_submission_id);
    End Loop;

    If p_clear_header Then
        Delete From clearing_house.tbl_clearinghouse_submissions Where submission_id = p_submission_id;
        Perform setval(pg_get_serial_sequence('clearing_house.tbl_clearinghouse_submissions', 'submission_id'), coalesce(max(submission_id), 0) + 1, false)
        From clearing_house.tbl_clearinghouse_submissions;
    End If;

    -- Raise Notice 'Done!';
End $$ Language plpgsql;

/*****************************************************************************************************************************
**	Function	fn_get_submission_table_column_names
**	Who			Roger Mähler
**	When		2013-10-14
**	What		Returns column names for specified table as an array
**	Uses
**	Used By
**	Revisions
******************************************************************************************************************************/
-- Select clearing_house.fn_get_submission_table_column_names(2, 'tbl_abundances')
Create Or Replace Function clearing_house.fn_get_submission_table_column_names(p_submission_id int, p_table_name_underscored character varying(255))
Returns character varying(255)[] As $$
    Declare v_columns character varying(255)[];
Begin
    Select array_agg(c.column_name_underscored order by c.column_id asc) Into v_columns
    From clearing_house.tbl_clearinghouse_submission_tables t
    Join clearing_house.tbl_clearinghouse_submission_xml_content_columns c
      On c.table_id = t.table_id
    Where c.submission_id = p_submission_id
      And t.table_name_underscored = p_table_name_underscored
    Group By c.submission_id, t.table_name;
    return v_columns;
End $$ Language plpgsql;

/*****************************************************************************************************************************
**	Function
**	Who			Roger Mähler
**	When		2013-10-14
**	What		Returns column SQL types for specified table as an array
**	Uses
**	Used By
**	Revisions
******************************************************************************************************************************/
-- Select clearing_house.fn_get_submission_table_column_types(2, 'tbl_abundances')
Create Or Replace Function clearing_house.fn_get_submission_table_column_types(p_submission_id int, p_table_name_underscored character varying(255))
Returns character varying(255)[] As $$
    Declare columns character varying(255)[];
Begin
    Select array_agg(clearing_house.fn_java_type_to_PostgreSQL(c.data_type) order by c.column_id asc) Into columns
    From clearing_house.tbl_clearinghouse_submission_tables t
    Join clearing_house.tbl_clearinghouse_submission_xml_content_columns c
      On c.table_id = t.table_id
    Where c.submission_id = p_submission_id
      And t.table_name_underscored = p_table_name_underscored
    Group By c.submission_id, t.table_name;
    return columns;
End $$ Language plpgsql;

Create Or Replace Function clearing_house.fn_get_submission_table_value_field_array(p_submission_id int, p_table_name_underscored text)
Returns character varying(255)[] As $$
Declare
    v_types character varying(255)[];
    v_fields character varying(255)[];
Begin

    /**
    **	Function    fn_get_submission_table_value_field_array
    **	Who			Roger Mähler
    **	When		2018-07-01
    **	What		Returns dynamic array of fields, types and name used in select query from XML value table
    **	Uses
    **	Used By
    **	Revisions
    **/

    v_types := clearing_house.fn_get_submission_table_column_types(p_submission_id, p_table_name_underscored);
    Select array_agg(format('values[%s]::%s', column_id, replace(column_type, 'integer', 'float::integer')) Order By column_id)
        Into v_fields
    From unnest(v_types) WITH ORDINALITY AS a(column_type, column_id);
    Return v_fields;
End $$ Language plpgsql;

Create Or Replace Function clearing_house.fn_select_xml_content_tables(p_submission_id int)
Returns Table(
    submission_id int,
    table_name    character varying(255),
    row_count     int
) As $$
Begin

    /**
    **	Who			Roger Mähler
    **	When		2013-10-14
    **	What		Returns all listed tables in a submission XML
    **  Note
    **	Uses
    **	Used By
    **	Revisions
    **/

    Return Query
        Select	d.submission_id																as submission_id,
                substring(d.xml::text from '^<([[:alnum:]]+).*>')::character varying(255)	as table_name,
                (xpath('//@length', d.xml))[1]::text::int								    as row_count
        From (
            Select x.submission_id, unnest(xpath('/sead-data-upload/*', x.xml)) As xml
            From clearing_house.tbl_clearinghouse_submissions as x
            Where 1 = 1
              And x.submission_id = p_submission_id
              And Not xml Is Null
              And xml Is Document
        ) d;
End $$ Language plpgsql;

/*****************************************************************************************************************************
**	Function	fn_select_xml_content_columns
**	Who			Roger Mähler
**	When		2013-10-14
**	What		Returns all listed columns in a submission XML
**  Note        First (not cloned) record per table is selected
**	Uses
**	Used By     fn_extract_and_store_submission_columns
**	Revisions
******************************************************************************************************************************/
-- Select * From clearing_house.fn_select_xml_content_columns(3)
Create Or Replace Function clearing_house.fn_select_xml_content_columns(p_submission_id int)
Returns Table(
    submission_id int,
    table_name	  character varying(255),
    column_name	  character varying(255),
    column_type	  character varying(255)
) As $$
Begin
    Return Query
        Select	d.submission_id                                   							as submission_id,
                d.table_name																as table_name,
                substring(d.xml::text from '^<([[:alnum:]]+).*>')::character varying(255)	as column_name,
                (xpath('//@class', d.xml))[1]::character varying(255)					as column_type
        From (
            Select x.submission_id, t.table_name, unnest(xpath('/sead-data-upload/' || t.table_name || '/*[not(@clonedId)][1]/*', xml)) As xml
            From clearing_house.tbl_clearinghouse_submissions x
            Join clearing_house.fn_select_xml_content_tables(p_submission_id) t
              On t.submission_id = x.submission_id
            Where 1 = 1
              And x.submission_id = p_submission_id
              And Not xml Is Null
              And xml Is Document
        ) as d;
End $$ Language plpgsql;

CREATE OR REPLACE FUNCTION clearing_house.fn_select_xml_content_records(p_submission_id integer)
  RETURNS TABLE(submission_id integer, table_name character varying, local_db_id integer, public_db_id_attr integer, public_db_id_tag integer) AS
$BODY$
Begin

    /**
    **	Function	fn_select_xml_content_records
    **	Who			Roger Mähler
    **	When		2013-10-14
    **	What		Returns all individual records found in a submission XML
    **  Note
    **	Uses
    **	Used By     fn_extract_and_store_submission_records
    **	Revisions
    **/

    Return Query
        With submission_xml_data_rows As (
            Select x.submission_id,
                   unnest(xpath('/sead-data-upload/*/*', x.xml)) As xml
            From clearing_house.tbl_clearinghouse_submissions x
            Where Not xml Is Null
              And xml Is Document
              And x.submission_id = p_submission_id
        )
            Select v.submission_id,
                   v.table_name::character varying(255),
                   Case When v.local_db_id ~ '^[0-9\.]+$' Then v.local_db_id::numeric::int Else Null End,
                   Case When v.public_db_id_attribute ~ '^[0-9\.]+$' Then v.public_db_id_attribute::numeric::int Else Null End,
                   Case When v.public_db_id_value ~ '^[0-9\.]+$' Then v.public_db_id_value::numeric::int Else Null End
            From (
                Select	d.submission_id																			as submission_id,
                        replace(substring(d.xml::text from '^<([[:alnum:]\.]+).*>'), 'com.sead.database.', '')	as table_name,
                        ((xpath('//@id', d.xml))[1])::character varying(255)									as local_db_id,
                        ((xpath('//@clonedId', d.xml))[1])::character varying(255)							as public_db_id_attribute,
                        ((xpath('//clonedId/text()', d.xml))[1])::character varying(255)						as public_db_id_value
                From submission_xml_data_rows as d
            ) As v;

End $BODY$ LANGUAGE plpgsql VOLATILE;

CREATE OR REPLACE FUNCTION clearing_house.fn_select_xml_content_values(p_submission_id integer, p_table_name character varying)
RETURNS TABLE(
    submission_id integer,
    table_name character varying,
    local_db_id integer,
    public_db_id integer,
    column_name character varying,
    column_type character varying,
    fk_local_db_id integer,
    fk_public_db_id integer,
    value text)
LANGUAGE 'plpgsql'
AS $BODY$
Begin
    /**
    **	Function	fn_select_xml_content_values
    **	Who			Roger Mähler
    **	When		2013-10-14
    **	What		Returns all values found in a submission XML
    **  Note
    **	Uses
    **	Used By     fn_extract_and_store_submission_values
    **	Revisions
    **/

    p_table_name := Coalesce(p_table_name, '*');
    Return Query
        With record_xml As (
            Select x.submission_id, unnest(xpath('/sead-data-upload/' || p_table_name || '/*', x.xml))			As xml
            From clearing_house.tbl_clearinghouse_submissions x
            Where x.submission_id = p_submission_id
              And Not x.xml Is Null
              And x.xml Is Document
        ), record_value_xml As (
            Select	x.submission_id																				As submission_id,
                    replace(substring(x.xml::text from '^<([[:alnum:]\.]+).*>'), 'com.sead.database.', '')		As table_name,
                    nullif((xpath('//@id', x.xml))[1]::character varying(255), 'NULL')::numeric::int			As local_db_id,
                    nullif((xpath('//@clonedId', x.xml))[1]::character varying(255), 'NULL')::numeric::int	    As public_db_id,
                    unnest(xpath( '/*/*', x.xml))																As xml
            From record_xml x
        )   Select	x.submission_id																				As submission_id,
                    x.table_name::character varying																As table_name,
                    x.local_db_id																				As local_db_id,
                    x.public_db_id																				As public_db_id,
                    substring(x.xml::character varying(255) from '^<([[:alnum:]]+).*>')::character varying(255)	As column_name,
                    nullif((xpath('//@class', x.xml))[1]::character varying, 'NULL')::character varying		    As column_type,
                    nullif((xpath('//@id', x.xml))[1]::character varying(255), 'NULL')::numeric::int			As fk_local_db_id,
                    nullif((xpath('//@clonedId', x.xml))[1]::character varying(255), 'NULL')::numeric::int	    As fk_public_db_id,
                    nullif((xpath('//text()', x.xml))[1]::text, 'NULL')::text									As value
            From record_value_xml x;
End
$BODY$;

Create Or Replace Function clearing_house.fn_extract_and_store_submission_tables(p_submission_id int) Returns void As $$
Begin

    /**
    **	Function	fn_extract_and_store_submission_tables
    **	Who			Roger Mähler
    **	When		2013-10-14
    **	What        Extracts and stores tables found in XML
    **  Note
    **	Uses        fn_select_xml_content_tables
    **	Used By     fn_explode_submission_xml_to_rdb
    **	Revisions
    **/

    -- TODO Move to import client

    /* Register new tables not previously encountered */
    Insert Into clearing_house.tbl_clearinghouse_submission_tables (table_name, table_name_underscored)
        Select t.table_name, clearing_house.fn_pascal_case_to_underscore(t.table_name)
        From  clearing_house.fn_select_xml_content_tables(p_submission_id) t
        Left Join clearing_house.tbl_clearinghouse_submission_tables x
          On x.table_name = t.table_name
        Where x.table_name Is NULL;

    /* Store all tables that exists in submission */
    Insert Into clearing_house.tbl_clearinghouse_submission_xml_content_tables (submission_id, table_id, record_count)
        Select t.submission_id, x.table_id, t.row_count
        From  clearing_house.fn_select_xml_content_tables(p_submission_id) t
        Join clearing_house.tbl_clearinghouse_submission_tables x
          On x.table_name = t.table_name
        ;
End $$ Language plpgsql;

Create Or Replace Function clearing_house.fn_extract_and_store_submission_columns(p_submission_id int) Returns void As $$
Begin

    /**
    **	Function	fn_extract_and_store_submission_columns
    **	Who			Roger Mähler
    **	When		2013-10-14
    **	What		Extract all unique column names from XML per table
    **  Note
    **	Uses
    **	Used By     fn_explode_submission_xml_to_rdb
    **	Revisions
    **/

    Delete From clearing_house.tbl_clearinghouse_submission_xml_content_columns
        Where submission_id = p_submission_id;

    Insert Into clearing_house.tbl_clearinghouse_submission_xml_content_columns (submission_id, table_id, column_name, column_name_underscored, data_type, fk_flag, fk_table, fk_table_underscored)
        Select	c.submission_id,
                t.table_id,
                c.column_name,
                clearing_house.fn_pascal_case_to_underscore(c.column_name),
                c.column_type,
                left(c.column_type, 18) = 'com.sead.database.',
                Case When left(c.column_type, 18) = 'com.sead.database.' Then substring(c.column_type from 19) Else Null End,
                ''
        From  clearing_house.fn_select_xml_content_columns(p_submission_id) c
        Join clearing_house.tbl_clearinghouse_submission_tables t
          On t.table_name = c.table_name
        Where c.submission_id = p_submission_id;

    Update clearing_house.tbl_clearinghouse_submission_xml_content_columns
        Set fk_table_underscored = clearing_house.fn_pascal_case_to_underscore(fk_table)
    Where submission_id = p_submission_id;

End $$ Language plpgsql;

-- Select clearing_house.fn_extract_and_store_submission_records(2)
Create Or Replace Function clearing_house.fn_extract_and_store_submission_records(p_submission_id int) Returns void As $$
Begin
    /**
    **	Function  fn_extract_and_store_submission_records
    **	Who       Roger Mähler
    **	When      2013-10-14
    **	What      Stores all unique table rows found in XML in tbl_clearinghouse_submission_xml_content_records
    **  Note
    **	Uses      fn_select_xml_content_records
    **	Used By   fn_explode_submission_xml_to_rdb
    **	Revisions
    **/

    Delete From clearing_house.tbl_clearinghouse_submission_xml_content_records
        Where submission_id = p_submission_id;

    /* Extract all unique records */
    Insert Into clearing_house.tbl_clearinghouse_submission_xml_content_records (submission_id, table_id, local_db_id, public_db_id)
        Select r.submission_id, t.table_id, r.local_db_id, coalesce(r.public_db_id_tag, public_db_id_attr)
        From clearing_house.fn_select_xml_content_records(p_submission_id) r
        Join clearing_house.tbl_clearinghouse_submission_tables t
          On t.table_name = r.table_name
        Where r.submission_id = p_submission_id;

    --Raise Notice 'XML record headers extracted and stored for submission id %', p_submission_id;

End $$ Language plpgsql;
/*****************************************************************************************************************************
**	Function	fn_extract_and_store_submission_values
**	Who			Roger Mähler
**	When		2013-10-14
**	What		Extract values from XML and store in generic table clearing_house.tbl_clearinghouse_submission_xml_content_values
**  Note
**	Uses
**	Used By     fn_explode_submission_xml_to_rdb
**	Revisions
******************************************************************************************************************************/
-- Select clearing_house.fn_extract_and_store_submission_values(2)
Create Or Replace Function clearing_house.fn_extract_and_store_submission_values(p_submission_id int) Returns void As $$
    Declare x RECORD;
Begin

    Delete From clearing_house.tbl_clearinghouse_submission_xml_content_values
        Where submission_id = p_submission_id;

    Insert Into clearing_house.tbl_clearinghouse_submission_xml_content_values (submission_id, table_id, local_db_id, column_id, fk_flag, fk_local_db_id, fk_public_db_id, value)
        Select	p_submission_id,
                t.table_id,
                v.local_db_id,
                c.column_id,
                Not (v.fk_local_db_id Is Null),
                v.fk_local_db_id,
                v.fk_public_db_id,
                Case When v.value = 'NULL' Then NULL Else v.value End
        From clearing_house.fn_select_xml_content_values(p_submission_id, '*') v
        Join clearing_house.tbl_clearinghouse_submission_tables t
            On t.table_name = v.table_name
        Join clearing_house.tbl_clearinghouse_submission_xml_content_columns c
          On c.submission_id = v.submission_id
         And c.table_id = t.table_id
         And c.column_name = v.column_name;

/*    For x In (Select t.*
              From clearing_house.tbl_clearinghouse_submission_tables t
              Join clearing_house.tbl_clearinghouse_submission_xml_content_tables c
                On c.table_id = t.table_id
              Where c.submission_id = p_submission_id)
    Loop
        Insert Into clearing_house.tbl_clearinghouse_submission_xml_content_values (submission_id, table_id, local_db_id, column_id, fk_flag, fk_local_db_id, fk_public_db_id, value)
            Select	p_submission_id,
                    t.table_id,
                    v.local_db_id,
                    c.column_id,
                    Not (v.fk_local_db_id Is Null),
                    v.fk_local_db_id,
                    v.fk_public_db_id,
                    Case When v.value = 'NULL' Then NULL Else v.value End
            From clearing_house.fn_select_xml_content_values(p_submission_id, x.table_name) v
            Join clearing_house.tbl_clearinghouse_submission_tables t
              On t.table_name = v.table_name
            Join clearing_house.tbl_clearinghouse_submission_xml_content_columns c
              On c.submission_id = v.submission_id
             And c.table_id = t.table_id
             And c.column_name = v.column_name;
    End Loop;
*/
End $$ Language plpgsql;

/*****************************************************************************************************************************
**	Function	fn_copy_extracted_values_to_entity_table
**	Who			Roger Mähler
**	When		2013-10-14
**	What		Copies explodes (vertical) XML data to corresponding CHDB table
**  Note        Note that CHDB table is in underscore notation e.g. "tblAbundances"
**	Uses        fn_get_submission_table_column_names, fn_get_submission_table_column_types
**	Used By     fn_explode_submission_xml_to_rdb
**	Revisions
******************************************************************************************************************************/

Create Or Replace View clearing_house.view_clearinghouse_local_fk_references As

    /*
    **	Who			Roger Mähler
    **	When		2013-11-06
    **	What		Gives FK-column that references a local record in the CHDB database
    **  Note        fn_copy_extracted_values_to_entity_table
    **	Uses        fn_get_submission_table_column_names, fn_get_submission_table_column_types
    **	Used By     fn_explode_submission_xml_to_rdb
    **	Revisions
    **/

    with sead_rdb_schema_pk_columns as (
        Select table_schema, table_name, column_name
        From clearing_house.fn_dba_get_sead_public_db_schema('public', 'sead_master')
        Where is_pk = 'YES'
    )
        Select v.submission_id, v.local_db_id, c.table_id, c.column_id,
                v.fk_local_db_id, fk_t.table_id as fk_table_id, fk_c.column_id as fk_column_id
        From clearing_house.tbl_clearinghouse_submission_xml_content_values v
        Join clearing_house.tbl_clearinghouse_submission_xml_content_columns c
            On c.submission_id = v.submission_id
            And c.table_id = v.table_id
            And c.column_id = v.column_id
        Join clearing_house.tbl_clearinghouse_submission_tables fk_t
            On fk_t.table_name_underscored = c.fk_table_underscored
        Join sead_rdb_schema_pk_columns s
            On s.table_schema = 'public'
            And s.table_name = fk_t.table_name_underscored
        Join clearing_house.tbl_clearinghouse_submission_xml_content_columns fk_c
            On fk_c.submission_id = v.submission_id
            And fk_c.table_id = fk_t.table_id
            And fk_c.column_name_underscored = s.column_name
        Join clearing_house.tbl_clearinghouse_submission_xml_content_values fk_v
            On fk_v.submission_id = v.submission_id
            And fk_v.table_id = fk_t.table_id
            And fk_v.column_id = fk_c.column_id
            And fk_v.local_db_id = v.fk_local_db_id
        Where v.fk_flag = true;

-- TODO: Review how public_db_id (cloned_db) are handled. They are filtered out from the following funciton since they have no attrbute values (only id)
Create Or Replace Function clearing_house.fn_get_extracted_values_as_arrays(p_submission_id int, p_table_name_underscored character varying(255))
Returns Table(
    submission_id int,
    table_name character varying(255),
    local_db_id int,
    public_db_id int,
    row_values text[]
) As $$
Declare v_table_id int;
Declare v_table_name character varying(255);
Begin

    /*
    ** Helper function for clearing_house.fn_copy_extracted_values_to_entity_table
    */

    Select t.table_id, t.table_name Into STRICT v_table_id, v_table_name
    From clearing_house.tbl_clearinghouse_submission_tables t
    Where table_name_underscored = p_table_name_underscored;

    Return Query
        With fk_references as (
            Select *
            From clearing_house.view_clearinghouse_local_fk_references f
            Where f.submission_id = p_submission_id
              And f.table_id = v_table_id
        )
            Select p_submission_id, v_table_name, r.local_db_id, r.public_db_id, array_agg(
                Case when v.fk_flag = TRUE Then
                        Case When Not v.fk_public_db_id Is Null And f.fk_local_db_id Is Null
                        Then v.fk_public_db_id::text Else (-v.fk_local_db_id)::text End
                Else v.value End
                Order by c.column_id asc
            ) as values
            From clearing_house.tbl_clearinghouse_submission_xml_content_records r
            Join clearing_house.tbl_clearinghouse_submission_xml_content_columns c
              On c.submission_id = r.submission_id
             And c.table_id = r.table_id
            /* Left */ Join clearing_house.tbl_clearinghouse_submission_xml_content_values v
              On v.submission_id = r.submission_id
             And v.table_id = r.table_id
             And v.local_db_id = r.local_db_id
             And v.column_id = c.column_id
            /* Check if public record pointed to by FK exists in local DB. In such case set FK value to -fk_local_db_id */
            Left Join fk_references f
              On f.submission_id = r.submission_id
             And f.table_id = r.table_id
             And f.column_id = c.column_id
             And f.local_db_id = v.local_db_id
             And f.fk_local_db_id = v.fk_local_db_id
            Where 1 = 1
             And r.submission_id = p_submission_id
             And r.table_id = v_table_id
            Group By r.local_db_id, r.public_db_id;

End $$ Language plpgsql;

Create Or Replace Function clearing_house.fn_copy_extracted_values_to_entity_table(
    p_submission_id int,
    p_table_name_underscored character varying(255),
    p_dry_run boolean=FALSE
) Returns text As $$

    Declare v_field_names character varying(255)[];
    Declare v_fields character varying(255)[];

    Declare insert_columns_string text;
    Declare select_columns_string text;

    Declare v_sql text;
    Declare i integer;

Begin

    If clearing_house.fn_table_exists(p_table_name_underscored) = false Then
        Raise Exception 'Table does not exist: %', p_table_name_underscored;
        Return Null;
    End If;

    v_sql := format('Delete From clearing_house.%I Where submission_id = %s;', p_table_name_underscored, p_submission_id);

    If Not p_dry_run Then
        Execute v_sql;
    End If;

    v_field_names := clearing_house.fn_get_submission_table_column_names(p_submission_id, p_table_name_underscored);
    v_fields :=  clearing_house.fn_get_submission_table_value_field_array(p_submission_id, p_table_name_underscored);

    If Not (v_field_names is Null or array_length(v_field_names, 1) = 0) Then

        insert_columns_string := replace(array_to_string(v_field_names, ', '), 'cloned_id', 'public_db_id');

        Select string_agg(field_expr, ', ' Order By field_id)
            Into select_columns_string
        From (
            Select field_id, string_agg(field_part, ' AS ') As field_expr
            From (Values (v_fields), (v_field_names)) as T(a), unnest(T.a) WITH ORDINALITY x(field_part, field_id)
            Group By field_id
        ) As X;

        -- select_columns_string = string_agg(v_fields, ', '); -- Enough, but without column names

        v_sql := format('
        Insert Into clearing_house.%s (submission_id, source_id, local_db_id, %s)
            Select v.submission_id, 1 as source_id, -v.local_db_id, %s
            From clearing_house.fn_get_extracted_values_as_arrays(%s, ''%s'') as v(submission_id, table_name, local_db_id, public_db_id, values)
        ', p_table_name_underscored, insert_columns_string, select_columns_string, p_submission_id, p_table_name_underscored);

        If Not p_dry_run Then
            Execute v_sql;
        End If;

    End If;

    Return v_sql;

End $$ Language plpgsql;

-- Drop Function clearing_house.fn_clearinghouse_review_dataset_ceramic_values_client_data(int, int);
-- Select * From clearing_house.fn_clearinghouse_review_dataset_ceramic_values_client_data(1, null)
Create Or Replace Function clearing_house.fn_clearinghouse_review_dataset_ceramic_values_client_data(int, int)
Returns Table (

    local_db_id					int,
    method_id					int,
    dataset_name				character varying,
    sample_name					character varying,
    method_name					character varying,
    lookup_name				    character varying,
    measurement_value			character varying,

    public_db_id 				int,
    public_method_id			int,
    public_sample_name			character varying,
    public_method_name			character varying,
    public_lookup_name		    character varying,
    public_measurement_value	character varying,

    entity_type_id				int
) As $$
Declare
    entity_type_id int;
Begin

    entity_type_id := clearing_house.fn_get_entity_type_for('tbl_ceramics');

    Return Query
        With LDB As (
            Select	d.submission_id                         As submission_id,
                    d.source_id                             As source_id,
                    d.local_db_id 			                As local_dataset_id,
                    d.dataset_name 			                As local_dataset_name,
                    ps.local_db_id 			                As local_physical_sample_id,
                    m.local_db_id 			                As local_method_id,

                    d.public_db_id 			                As public_dataset_id,
                    ps.public_db_id 			            As public_physical_sample_id,
                    m.public_db_id 			                As public_method_id,

                    c.local_db_id                           As local_db_id,
                    c.public_db_id                          As public_db_id,

                    ps.sample_name                          As sample_name,
                    m.method_name                           As method_name,
                    cl.name                                 As lookup_name,
                    c.measurement_value                     As measurement_value,

                    cl.date_updated                     	As date_updated  -- Select count(*)

            From clearing_house.view_datasets d
            Join clearing_house.view_analysis_entities ae
              On ae.dataset_id = d.merged_db_id
             And ae.submission_id In (0, d.submission_id)
            Join clearing_house.view_ceramics c
              On c.analysis_entity_id = ae.merged_db_id
             And c.submission_id In (0, d.submission_id)
            Join clearing_house.view_ceramics_lookup cl
              On cl.merged_db_id = c.ceramics_lookup_id
             And cl.submission_id In (0, d.submission_id)
            Join clearing_house.view_physical_samples ps
              On ps.merged_db_id = ae.physical_sample_id
             And ps.submission_id In (0, d.submission_id)
            Join clearing_house.view_methods m
              On m.merged_db_id = d.method_id
             And m.submission_id In (0, d.submission_id)
           Where 1 = 1
              And d.submission_id = $1 -- perf
              And d.local_db_id = Coalesce(-$2, d.local_db_id) -- perf
        ), RDB As (
            Select	d.dataset_id 			                As dataset_id,
                    ps.physical_sample_id                   As physical_sample_id,
                    m.method_id                             As method_id,
                    c.ceramics_id                           As ceramics_id,
                    ps.sample_name                          As sample_name,
                    m.method_name                           As method_name,
                    cl.name                                 As lookup_name,
                    c.measurement_value                     As measurement_value
            From public.tbl_datasets d
            Join public.tbl_analysis_entities ae
              On ae.dataset_id = d.dataset_id
            Join public.tbl_ceramics c
              On c.analysis_entity_id = ae.analysis_entity_id
            Join public.tbl_ceramics_lookup cl
              On cl.ceramics_lookup_id = c.ceramics_lookup_id
            Join public.tbl_physical_samples ps
              On ps.physical_sample_id = ae.physical_sample_id
            Join public.tbl_methods m
              On m.method_id = d.method_id
            -- Where ae.dataset_id = public_ds_id -- perf
        )
            Select
                -- LDB.local_dataset_id 			                As dataset_id,
                -- LDB.local_physical_sample_id 			        As physical_sample_id,
                LDB.local_db_id                                 As local_db_id,
                LDB.local_method_id 			                As method_id,
                LDB.local_dataset_name							As dataset_name,
                LDB.sample_name									As sample_name,
                LDB.method_name									As method_name,
                LDB.lookup_name									As lookup_name,
                LDB.measurement_value							As measurement_value,

                -- LDB.public_dataset_id 			                As public_dataset_id,
                -- LDB.public_physical_sample_id 			        As public_physical_sample_id,
                LDB.public_db_id 			                    As public_db_id,
                LDB.public_method_id 			                As public_method_id,
                RDB.sample_name									As public_sample_name,
                RDB.method_name									As public_method_name,
                RDB.lookup_name									As public_lookup_name,
                RDB.measurement_value							As public_measurement_value,

                entity_type_id									As entity_type_id
            From LDB
            Left Join RDB
              On 1 = 1
             And RDB.ceramics_id = LDB.public_db_id
             --And RDB.dataset_id = LDB.public_dataset_id
             --And RDB.physical_sample_id = LDB.public_physical_sample_id
             --And RDB.method_id = LDB.public_method_id

            Where LDB.source_id = 1
              And LDB.submission_id = $1
              And LDB.local_dataset_id = Coalesce(-$2, LDB.local_dataset_id)
            Order by LDB.local_physical_sample_id;

End $$ Language plpgsql;

-- Drop Function clearing_house.fn_clearinghouse_review_ceramic_values_crosstab(p_submission_id int)
-- select * from clearing_house.fn_clearinghouse_review_ceramic_values_crosstab(1)
create or replace function clearing_house.fn_clearinghouse_review_ceramic_values_crosstab(p_submission_id int)
returns table (
    sample_name text,
    local_db_id int,
    public_db_id int,
    entity_type_id int,
    json_data_values json)
as $$
    declare
        v_category_sql text;
        v_source_sql text;
        v_typed_fields text;
        v_field_names text;
        v_column_names text;
        v_sql text;
begin
    v_category_sql = '
        select distinct name
        from clearing_house.view_ceramics_lookup
        order by name
    ';
    v_source_sql = format('
        select	sample_name,                                            -- row_name
                local_db_id, public_db_id, entity_type_id,              -- extra_columns
                lookup_name,                                            -- category
                ARRAY[lookup_name, ''text'', max(measurement_value), max(public_measurement_value)] as measurement_value
        from clearing_house.fn_clearinghouse_review_dataset_ceramic_values_client_data(%s, null) c
        where true
        group by sample_name, local_db_id, public_db_id, entity_type_id, lookup_name
        order by sample_name, lookup_name
    ', p_submission_id);

    select string_agg(format('%I text[]', name), ', ' order by name) as typed_fields,
           string_agg(format('ARRAY[%L, ''local'', ''public'']', name), ', ' order by name) AS column_names
    into v_typed_fields, v_field_names, v_column_names
    from clearing_house.view_ceramics_lookup;

    if v_column_names is null then

        return query
            select *
            from (values (null::text, null::int, null::int, null::int, null::json)) as v
            where false;

    else

        select format('
            select sample_name, local_db_id, public_db_id, entity_type_id, array_to_json(ARRAY[%s]) AS json_data_values
            from crosstab(%L, %L) AS ct(sample_name text, local_db_id int, public_db_id int, entity_type_id int, %s)',
                      v_column_names, v_source_sql, v_category_sql, v_typed_fields)
        into v_sql;

        return query execute v_sql;

    end if;

end
$$ language 'plpgsql';
/*****************************************************************************************************************************
**  Function    fn_clearinghouse_review_dataset_client_data
**	Who			Roger Mähler
**	When		2013-11-14
**	What		Returns dataset data used by client
**	Uses
**	Used By
**	Revisions
******************************************************************************************************************************/
-- Drop Function clearing_house.fn_clearinghouse_review_dataset_client_data(int, int)
-- Select * From clearing_house.fn_clearinghouse_review_dataset_client_data(2, 100)
Create Or Replace Function clearing_house.fn_clearinghouse_review_dataset_client_data(int, int)
Returns Table (

	local_db_id                     int,
	dataset_name                    character varying,
	data_type_name                  character varying,
	master_name                     character varying,
	previous_dataset_name           character varying,
	method_name                     character varying,
    project_name                    character varying,
    project_stage_name              text,
	record_type_id                  int,

	public_db_id                    int,
	public_dataset_name             character varying,
	public_data_type_name           character varying,
	public_master_name              character varying,
	public_previous_dataset_name    character varying,
	public_method_name              character varying,
	public_project_name             character varying,
	public_project_stage_name       text,
	public_record_type_id           int,

	entity_type_id                  int

) As $$

Declare
    entity_type_id int;

Begin

    entity_type_id := clearing_house.fn_get_entity_type_for('tbl_datasets');

	Return Query

		With sample (submission_id, source_id, local_db_id, public_db_id, merged_db_id, dataset_name, data_type_name, master_name, previous_dataset_name, method_name, project_name, project_stage_name, record_type_id) As (
            Select  d.submission_id                                         As submission_id,
                    d.source_id                                             As source_id,
                    d.local_db_id                                           As local_db_id,
                    d.public_db_id                                          As public_db_id,
                    d.merged_db_id                                          As merged_db_id,
                    d.dataset_name                                          As dataset_name,
                    dt.data_type_name                                       As data_type_name,
                    dm.master_name                                          As master_name,
                    ud.dataset_name                                         As previous_dataset_name,
                    m.method_name                                           As method_name,
                    p.project_name                                          As project_name,
                    format('%s, %s', pt.project_type_name, ps.stage_name)   As project_stage_name,
                    m.record_type_id                                        As record_type_id
                    /* Används för att skilja proxy types: 1) measured value 2) abundance */
            From clearing_house.view_datasets d
            Join clearing_house.view_data_types dt
              On dt.data_type_id = d.data_type_id
             And dt.submission_id In (0, d.submission_id)
            Left Join clearing_house.view_dataset_masters dm
              On dm.merged_db_id = d.master_set_id
             And dm.submission_id In (0, d.submission_id)
            Left Join clearing_house.view_datasets ud
              On ud.merged_db_id = d.updated_dataset_id
             And ud.submission_id In (0, d.submission_id)
            Join clearing_house.view_methods m
              On m.merged_db_id = d.method_id
             And m.submission_id In (0, d.submission_id)
            Left Join clearing_house.view_projects p
              On p.merged_db_id = d.project_id
             And p.submission_id In (0, d.submission_id)
            Left Join clearing_house.view_project_types pt
              On pt.merged_db_id = p.project_type_id
             And pt.submission_id In (0, d.submission_id)
            Left Join clearing_house.view_project_stages ps
              On ps.merged_db_id = p.project_stage_id
             And ps.submission_id In (0, d.submission_id)
		)
			Select
				LDB.local_db_id						As local_db_id,
				LDB.dataset_name                    As dataset_name,
				LDB.data_type_name                  As data_type_name,
				LDB.master_name                     As master_name,
				LDB.previous_dataset_name           As previous_dataset_name,
				LDB.method_name                     As method_name,
				LDB.project_name                    As project_name,
				LDB.project_stage_name              As project_stage_name,
				LDB.record_type_id                  As record_type_id,

				LDB.public_db_id					As public_db_id,
				RDB.dataset_name                    As public_dataset_name,
				RDB.data_type_name                  As public_data_type_name,
				RDB.master_name                     As public_master_name,
				RDB.previous_dataset_name           As public_previous_dataset_name,
				RDB.method_name                     As public_method_name,
				RDB.project_name                    As public_project_name,
				RDB.project_stage_name              As public_project_stage_name,
				RDB.record_type_id                  As public_record_type_id,

                entity_type_id

			From sample LDB
			Left Join sample RDB
			  On RDB.source_id = 2
			 And RDB.public_db_id = LDB.public_db_id
			Where LDB.source_id = 1
			  And LDB.submission_id = $1
			  And LDB.local_db_id = -$2
			  ;

End $$ Language plpgsql;

/*****************************************************************************************************************************
**	Function	fn_clearinghouse_review_dataset_contacts_client_data
**	Who			Roger Mähler
**	When		2013-11-13
**	What		Returns dataset contacts review data used by client
**	Uses
**	Used By
**	Revisions
******************************************************************************************************************************/
-- Drop Function clearing_house.fn_clearinghouse_review_dataset_contacts_client_data(int, int)
-- Select * From clearing_house.fn_clearinghouse_review_dataset_contacts_client_data(2, -40)
Create Or Replace Function clearing_house.fn_clearinghouse_review_dataset_contacts_client_data(int, int)
Returns Table (

	local_db_id					int,

    full_name					text,
    contact_type_name			character varying,

	public_db_id 				int,

    public_full_name			text,
    public_contact_type_name	character varying,

    date_updated				text,
	entity_type_id				int

) As $$
Declare
    entity_type_id int;
Begin

    entity_type_id := clearing_house.fn_get_entity_type_for('tbl_dataset_contacts');

	Return Query

		Select
			LDB.local_db_id				               					As local_db_id,

			format('%s %s', LDB.first_name, LDB.last_name)				As full_name,
			LDB.contact_type_name										As contact_type_name,

			LDB.public_db_id				            				As public_db_id,

			format('%s %s', RDB.first_name, RDB.last_name)				As public_full_name,
			RDB.contact_type_name										As public_contact_type_name,

			to_char(LDB.date_updated,'YYYY-MM-DD')						As date_updated,
			entity_type_id												As entity_type_id

		From (
			Select	d.source_id                                         As source_id,
					d.submission_id                                     As submission_id,
					d.local_db_id										As dataset_id,

					dc.local_db_id										As local_db_id,
					dc.public_db_id										As public_db_id,
					dc.merged_db_id										As merged_db_id,

					c.first_name										As first_name,
					c.last_name											As last_name,
					t.contact_type_name									As contact_type_name,

					dc.date_updated										As date_updated
			From clearing_house.view_datasets d
			Join clearing_house.view_dataset_contacts dc
			  On dc.dataset_id = d.merged_db_id
			 And dc.submission_id In (0, d.submission_id)
			Join clearing_house.view_contacts c
			  On c.merged_db_id = dc.contact_id
			 And c.submission_id In (0, d.submission_id)
			Join clearing_house.view_contact_types t
			  On t.merged_db_id = dc.contact_type_id
			 And t.submission_id In (0, d.submission_id)

		) As LDB Left Join (

			Select	d.dataset_id										As dataset_id,

					dc.contact_id										As contact_id,

					c.first_name										As first_name,
					c.last_name											As last_name,
					t.contact_type_name									As contact_type_name

			From public.tbl_datasets d
			Join public.tbl_dataset_contacts dc
			  On dc.dataset_id = d.dataset_id
			Join public.tbl_contacts c
			  On c.contact_id = dc.contact_id
			Join public.tbl_contact_types t
			  On t.contact_type_id = dc.contact_type_id

		  ) As RDB
		  On
		  RDB.contact_id = LDB.public_db_id
		Where LDB.source_id = 1
		  And LDB.submission_id = $1
		  And LDB.dataset_id = -$2
		;

End $$ Language plpgsql;

/*****************************************************************************************************************************
**	Function	fn_clearinghouse_review_dataset_submissions_client_data
**	Who			Roger Mähler
**	When		2013-11-13
**	What		Returns dataset submissions review data used by client
**	Uses
**	Used By
**	Revisions
******************************************************************************************************************************/
-- Drop Function clearing_house.fn_clearinghouse_review_dataset_submissions_client_data(int, int)
-- Select * From clearing_house.fn_clearinghouse_review_dataset_submissions_client_data(2, -40)
Create Or Replace Function clearing_house.fn_clearinghouse_review_dataset_submissions_client_data(int, int)
Returns Table (

	local_db_id					int,

    full_name					text,
    submission_type				character varying,
    notes						text,
    date_submitted				text,

	public_db_id 				int,

    public_full_name     		text,
    public_submission_type		character varying,
    public_notes				text,
    public_date_submitted		text,

    date_updated				text,
	entity_type_id				int

) As $$
Declare
    entity_type_id int;
Begin

    entity_type_id := clearing_house.fn_get_entity_type_for('tbl_dataset_submissions');

	Return Query

		Select

			LDB.local_db_id				               					As local_db_id,

			format('%s %s', LDB.first_name, LDB.last_name)				As last_name,
			LDB.submission_type											As submission_type,
			LDB.notes													As notes,
			to_char(LDB.date_submitted,'YYYY-MM-DD')					As date_submitted,

			LDB.public_db_id				            				As public_db_id,

			format('%s %s', RDB.first_name, RDB.last_name)				As public_full_name,
			RDB.submission_type											As public_submission_type,
			RDB.notes													As public_notes,
			to_char(RDB.date_submitted,'YYYY-MM-DD')					As public_date_submitted,

			to_char(LDB.date_updated,'YYYY-MM-DD')						As date_updated,

			entity_type_id												As entity_type_id

		From (

			Select	d.source_id                                         As source_id,
					d.submission_id                                     As submission_id,
					d.local_db_id										As dataset_id,
					d.public_db_id										As public_dataset_id,

					ds.local_db_id										As local_db_id,
					ds.public_db_id										As public_db_id,
					ds.merged_db_id										As merged_db_id,

					c.first_name										As first_name,
					c.last_name											As last_name,
					dst.submission_type									As submission_type,
					ds.notes											As notes,
					ds.date_submitted									As date_submitted,

					ds.date_updated

			From clearing_house.view_datasets d
			Join clearing_house.view_dataset_submissions ds
			  On ds.dataset_id = d.merged_db_id
			 And ds.submission_id In (0, d.submission_id)
			Join clearing_house.view_contacts c
			  On c.merged_db_id = ds.contact_id
			 And c.submission_id In (0, d.submission_id)
			Join clearing_house.view_dataset_submission_types dst
			  On dst.merged_db_id = ds.submission_type_id
			 And dst.submission_id In (0, d.submission_id)

		) As LDB Left Join (

			Select	d.dataset_id										As dataset_id,

					ds.dataset_submission_id							As dataset_submission_id,

					c.first_name										As first_name,
					c.last_name											As last_name,
					dst.submission_type									As submission_type,
					ds.notes											As notes,
					ds.date_submitted									As date_submitted,

					ds.date_updated

			From public.tbl_datasets d
			Join public.tbl_dataset_submissions ds
			  On ds.dataset_id = d.dataset_id
			Join public.tbl_contacts c
			  On c.contact_id = ds.contact_id
			Join public.tbl_dataset_submission_types dst
			  On dst.submission_type_id = ds.submission_type_id

		  ) As RDB
		  On RDB.dataset_submission_id = LDB.public_db_id
		Where LDB.source_id = 1
		  And LDB.submission_id = $1
		  And LDB.dataset_id = -$2;

End $$ Language plpgsql;

/*****************************************************************************************************************************
**  View        view_clearinghouse_dataset_measured_values
**	Who			Roger Mähler
**	When		2013-11-14
**	What
**	Uses
**	Used By
**	Revisions
******************************************************************************************************************************/
-- Drop View clearing_house.view_clearinghouse_dataset_measured_values
Create Or Replace View clearing_house.view_clearinghouse_dataset_measured_values As

    Select d.submission_id              as submission_id,
           d.source_id                  as source_id,
           d.local_db_id                as local_dataset_id,
           d.merged_db_id               as merged_dataset_id,
           d.public_db_id               as public_dataset_id,
           ps.sample_group_id           as sample_group_id,
           ps.merged_db_id              as physical_sample_id,
           ps.local_db_id              	as local_physical_sample_id,
           ps.public_db_id              as public_physical_sample_id,
           ps.sample_name               as sample_name,
           m.method_id                  as method_id,
           m.public_db_id               as public_method_id,
           m.method_name                as method_name,
           aepmm.method_id              as prep_method_id,
           aepmm.public_db_id           as public_prep_method_id,
           aepmm.method_name            as prep_method_name,
           mv.measured_value            as measured_value
    From clearing_house.view_datasets d
    Join clearing_house.view_analysis_entities ae
      On ae.dataset_id = d.merged_db_id
     And ae.submission_id In (0, d.submission_id)
    Join clearing_house.view_measured_values mv
      On mv.analysis_entity_id = ae.merged_db_id
     And mv.submission_id In (0, d.submission_id)
    Join clearing_house.view_physical_samples ps
      On ps.merged_db_id = ae.physical_sample_id
     And ps.submission_id In (0, d.submission_id)
    Join clearing_house.view_methods m
      On m.merged_db_id = d.method_id
     And m.submission_id In (0, d.submission_id)
    Left Join clearing_house.view_measured_value_dimensions mvd
      On mvd.measured_value_id = mv.merged_db_id
     And mvd.submission_id In (0, d.submission_id)
    Left Join clearing_house.view_dimensions dd
      On dd.merged_db_id = mvd.dimension_id
     And dd.submission_id In (0, d.submission_id)
    Left Join clearing_house.view_analysis_entity_prep_methods aepm
      On aepm.analysis_entity_id = ae.merged_db_id
     And aepm.submission_id In (0, d.submission_id)
    Left Join clearing_house.view_methods aepmm
      On aepmm.merged_db_id = aepm.method_id
     And aepmm.submission_id In (0, d.submission_id)
;

/*****************************************************************************************************************************
**  View        view_dataset_measured_values
**	Who			Roger Mähler
**	When		2013-11-14
**	What
**	Uses
**	Used By
**	Revisions
******************************************************************************************************************************/
-- Drop View clearing_house.view_dataset_measured_values
-- Select * From clearing_house.view_dataset_measured_values
Create Or Replace View clearing_house.view_dataset_measured_values As

    Select d.dataset_id                 as dataset_id,
           ps.physical_sample_id        as physical_sample_id,
           ps.sample_group_id           as sample_group_id,
           ps.sample_name               as sample_name,
           m.method_id                  as method_id,
           m.method_name                as method_name,
           aepmm.method_id              as prep_method_id,
           aepmm.method_name            as prep_method_name,
           mv.measured_value            as measured_value
    From public.tbl_datasets d
    Join public.tbl_analysis_entities ae
      On ae.dataset_id = d.dataset_id
    Join public.tbl_measured_values mv
      On mv.analysis_entity_id = ae.analysis_entity_id
    Join public.tbl_physical_samples ps
      On ps.physical_sample_id = ae.physical_sample_id
    Join public.tbl_methods m
      On m.method_id = d.method_id
    Left Join public.tbl_measured_value_dimensions mvd
      On mvd.measured_value_id = mv.measured_value_id
    Left Join public.tbl_dimensions dd
      On dd.dimension_id = mvd.dimension_id
    Left Join public.tbl_analysis_entity_prep_methods aepm
      On aepm.analysis_entity_id = ae.analysis_entity_id
    Left Join public.tbl_methods aepmm
      On aepmm.method_id = aepm.method_id
;

/*****************************************************************************************************************************
**	Function	fn_clearinghouse_review_dataset_measured_values_client_data
**	Who			Roger Mähler
**	When		2013-11-13
**	What		Returns dataset measured value review data used by client
**	Uses
**	Used By
**	Revisions
******************************************************************************************************************************/
-- Drop Function clearing_house.fn_clearinghouse_review_dataset_measured_values_client_data(int, int)
-- Select * From clearing_house.fn_clearinghouse_review_dataset_measured_values_client_data(2, 140)
Create Or Replace Function clearing_house.fn_clearinghouse_review_dataset_measured_values_client_data(int, int)
Returns Table (

	local_db_id					int,
	public_db_id 				int,

    sample_name					character varying,

    method_id					int,
    method_name					character varying,
    prep_method_id				int,
    prep_method_name			character varying,

    measured_value				numeric(20,10),
    public_measured_value		numeric(20,10),

	entity_type_id				int

) As $$
Declare
    entity_type_id int;
    public_ds_id int;

Begin

    entity_type_id := clearing_house.fn_get_entity_type_for('tbl_physical_samples');

	Select x.public_db_id Into public_ds_id
	From clearing_house.view_datasets x
	Where x.local_db_id = -$2;

	Return Query

		Select

			LDB.physical_sample_id				               			As local_db_id,
			RDB.physical_sample_id				               			As public_db_id,

			LDB.sample_name												As sample_name,

			LDB.method_id												As method_id,
			LDB.method_name												As method_name,
			LDB.prep_method_id											As prep_method_id,
			LDB.prep_method_name										As prep_method_name,

			LDB.measured_value											As measured_value,

			RDB.measured_value											As public_measured_value,

			entity_type_id												As entity_type_id

		From clearing_house.view_clearinghouse_dataset_measured_values LDB
		Left Join clearing_house.view_dataset_measured_values RDB
		  On RDB.dataset_id = public_ds_id
		 And RDB.physical_sample_id = LDB.public_physical_sample_id
		 And RDB.method_id = LDB.public_method_id
		 And RDB.prep_method_id = LDB.public_prep_method_id
		Where LDB.source_id = 1
		  And LDB.submission_id = $1
		  And LDB.local_dataset_id = -$2;

End $$ Language plpgsql;
 /*****************************************************************************************************************************
**  View        view_dataset_abundance_modification_types
**	Who			Roger Mähler
**	When		2013-12-09
**	What
**	Uses
**	Used By
**	Revisions
******************************************************************************************************************************/
-- Drop View clearing_house.view_dataset_abundance_modification_types

Create Or Replace View clearing_house.view_dataset_abundance_modification_types As

     select	am.abundance_id														as abundance_id,
			array_to_string(array_agg(mt.modification_type_description), ',')	as modification_type_description,
			array_to_string(array_agg(mt.modification_type_name), ',')			as modification_type_name
	from public.tbl_abundance_modifications am
	left join public.tbl_modification_types mt
	  on mt.modification_type_id = am.modification_type_id
	group by am.abundance_id

	;

/*****************************************************************************************************************************
**  View        view_dataset_abundance_ident_levels
**	Who			Roger Mähler
**	When		2013-12-09
**	What
**	Uses
**	Used By
**	Revisions
******************************************************************************************************************************/
-- Drop View clearing_house.view_dataset_abundances

Create Or Replace View clearing_house.view_dataset_abundance_ident_levels As

     select	al.abundance_id														as abundance_id,
			array_to_string(array_agg(l.identification_level_abbrev), ',')		as identification_level_abbrev,
			array_to_string(array_agg(l.identification_level_name), ',')		as identification_level_name
	from public.tbl_abundance_ident_levels al
	left join public.tbl_identification_levels l
	  on l.identification_level_id = al.identification_level_id
	group by al.abundance_id

	;

/*****************************************************************************************************************************
**  View        view_dataset_abundance_element_names
**	Who			Roger Mähler
**	When		2013-12-09
**	What
**	Uses
**	Used By
**	Revisions
******************************************************************************************************************************/
-- Drop View clearing_house.view_dataset_abundance_element_names

Create Or Replace View clearing_house.view_dataset_abundance_element_names As

    select	a.abundance_id										as abundance_id,
			array_to_string(array_agg(ael.element_name), ',')	as element_name
	from public.tbl_abundances a
	join public.tbl_abundance_elements ael
	  on ael.abundance_element_id = a.abundance_element_id
	group by a.abundance_id

	;

/*****************************************************************************************************************************
**  View        view_dataset_abundances
**	Who			Roger Mähler
**	When		2013-12-09
**	What
**	Uses
**	Used By
**	Revisions
******************************************************************************************************************************/
-- Drop View clearing_house.view_dataset_abundances
-- Select * From clearing_house.view_dataset_abundances
Create Or Replace View clearing_house.view_dataset_abundances As

     select	d.dataset_id								as dataset_id,

            ttm.taxon_id                                as taxon_id,
			ttg.genus_name								as genus_name,
			ttm.species									as species,

			ps.physical_sample_id						as physical_sample_id,
			ps.sample_name              				as sample_name,

            a.abundance_id                              as abundance_id,
			a.abundance									as abundance,

			Coalesce(ael.element_name, '')				as element_name,
			Coalesce(mt.modification_type_name, '')		as modification_type_name,
			Coalesce(il.identification_level_name, '')	as identification_level_name

	from public.tbl_datasets d
	left join public.tbl_analysis_entities ae
	  on d.dataset_id= ae.dataset_id
	left join public.tbl_physical_samples ps
	  on  ae.physical_sample_id = ps.physical_sample_id
	left join public.tbl_abundances a
	  on a.analysis_entity_id = ae.analysis_entity_id
	left join public.tbl_taxa_tree_master ttm
	  on ttm.taxon_id = a.taxon_id
	left join public.tbl_taxa_tree_genera ttg
	  on ttg.genus_id =  ttm.genus_id
	left join clearing_house.view_dataset_abundance_modification_types mt
	  on mt.abundance_id = a.abundance_id
	left join clearing_house.view_dataset_abundance_ident_levels il
	  on il.abundance_id = a.abundance_id
	left join clearing_house.view_dataset_abundance_element_names ael
	  on ael.abundance_id = a.abundance_id
	where 1 = 1
	;


/*****************************************************************************************************************************
**  View        view_clearinghouse_dataset_abundance_modification_types
**	Who			Roger Mähler
**	When		2013-12-09
**	What
**	Uses
**	Used By
**	Revisions
******************************************************************************************************************************/
-- Drop View clearing_house.view_clearinghouse_dataset_abundance_modification_types

Create Or Replace View clearing_house.view_clearinghouse_dataset_abundance_modification_types As

     select	am.submission_id                                                    as submission_id,
            am.abundance_id														as abundance_id,
            am.merged_db_id														as merged_db_id,
            am.public_db_id														as public_db_id,
            am.local_db_id														as local_db_id,
			array_to_string(array_agg(mt.modification_type_description), ',')	as modification_type_description,
			array_to_string(array_agg(mt.modification_type_name), ',')			as modification_type_name
	from clearing_house.view_abundance_modifications am
	left join clearing_house.view_modification_types mt
	  on mt.merged_db_id = am.modification_type_id
	 and mt.submission_id In (0, am.submission_id)
	group by am.submission_id, am.abundance_id, am.merged_db_id, am.public_db_id, am.local_db_id

	;

/*****************************************************************************************************************************
**  View        view_clearinghouse_dataset_abundance_ident_levels
**	Who			Roger Mähler
**	When		2013-12-09
**	What
**	Uses
**	Used By
**	Revisions
******************************************************************************************************************************/
-- Drop View clearing_house.view_clearinghouse_dataset_abundance_ident_levels

Create Or Replace View clearing_house.view_clearinghouse_dataset_abundance_ident_levels As

     select	al.submission_id                                                    as submission_id,
            al.abundance_id														as abundance_id,
            al.merged_db_id														as merged_db_id,
            al.public_db_id														as public_db_id,
            al.local_db_id														as local_db_id,
			array_to_string(array_agg(l.identification_level_abbrev), ',')		as identification_level_abbrev,
			array_to_string(array_agg(l.identification_level_name), ',')		as identification_level_name
	from clearing_house.view_abundance_ident_levels al
	left join clearing_house.view_identification_levels l
	  on l.identification_level_id = al.identification_level_id
	group by al.submission_id, al.abundance_id, al.merged_db_id, al.public_db_id, al.local_db_id

	;

/*****************************************************************************************************************************
**  View        view_clearinghouse_dataset_abundance_element_names
**	Who			Roger Mähler
**	When		2013-12-09
**	What
**	Uses
**	Used By
**	Revisions
******************************************************************************************************************************/
-- Drop View clearing_house.view_clearinghouse_dataset_abundance_element_names

Create Or Replace View clearing_house.view_clearinghouse_dataset_abundance_element_names As

    select  a.submission_id                                     as submission_id,
            a.abundance_id										as abundance_id,
            a.merged_db_id										as merged_db_id,
            a.public_db_id										as public_db_id,
            a.local_db_id										as local_db_id,
			array_to_string(array_agg(ael.element_name), ',')	as element_name
	from clearing_house.view_abundances a
	join clearing_house.view_abundance_elements ael
	  on ael.abundance_element_id = a.abundance_element_id
	group by a.submission_id, a.abundance_id, a.merged_db_id, a.public_db_id, a.local_db_id

;

/*****************************************************************************************************************************
**  View        view_clearinghouse_dataset_abundances
**	Who			Roger Mähler
**	When		2013-12-09
**	What
**	Uses
**	Used By
**	Revisions
******************************************************************************************************************************/
-- Drop View clearing_house.view_clearinghouse_dataset_abundances
-- Select * From clearing_house.view_clearinghouse_dataset_abundances
Create Or Replace View clearing_house.view_clearinghouse_dataset_abundances As

     select	d.submission_id								as submission_id,
			d.source_id 								as source_id,
			d.local_db_id								as local_dataset_id,
			d.public_db_id								as public_dataset_id,

			a.abundance_id								as abundance_id,
			a.local_db_id								as local_db_id,
			a.public_db_id								as public_db_id,
			a.abundance									as abundance,

			ttm.taxon_id								as taxon_id,
			ttm.public_db_id							as public_taxon_id,
			ttg.genus_name								as genus_name,
			ttm.species									as species,
			tta.author_name								as author_name,

			ps.physical_sample_id						as physical_sample_id,
			ps.public_db_id								as public_physical_sample_id,
			ps.sample_name              				as sample_name,

			Coalesce(ael.element_name, '')				as element_name,
			Coalesce(mt.modification_type_name, '')		as modification_type_name,
			Coalesce(il.identification_level_name, '')	as identification_level_name

	from clearing_house.view_datasets d
	join clearing_house.view_analysis_entities ae
	  on ae.dataset_id = d.merged_db_id
     And ae.submission_id In (0, d.submission_id)
	join clearing_house.view_physical_samples ps
	  on ps.merged_db_id = ae.physical_sample_id
     And ps.submission_id In (0, d.submission_id)
	join clearing_house.view_abundances a
	  on a.analysis_entity_id = ae.merged_db_id
     And a.submission_id In (0, d.submission_id)
	left join clearing_house.view_taxa_tree_master ttm
	  on ttm.merged_db_id = a.taxon_id
     And ttm.submission_id In (0, d.submission_id)
	left join clearing_house.view_taxa_tree_genera ttg
	  on ttg.merged_db_id =  ttm.genus_id
     And ttg.submission_id In (0, d.submission_id)
	left join clearing_house.view_taxa_tree_authors tta
	  on tta.merged_db_id =  ttm.author_id
     And tta.submission_id In (0, d.submission_id)
	left join clearing_house.view_clearinghouse_dataset_abundance_modification_types mt
	  on mt.abundance_id = a.merged_db_id
     And mt.submission_id In (0, d.submission_id)
	left join clearing_house.view_clearinghouse_dataset_abundance_ident_levels il
	  on il.abundance_id = a.merged_db_id
     And il.submission_id In (0, d.submission_id)
	left join clearing_house.view_clearinghouse_dataset_abundance_element_names ael
	  on ael.abundance_id = a.merged_db_id
     And ael.submission_id In (0, d.submission_id)
	where 1 = 1
	;

/*****************************************************************************************************************************
**	Function	fn_clearinghouse_review_dataset_abundance_values_client_data
**	Who			Roger Mähler
**	When		2013-12-09
**	What		Returns dataset abundance values review data used by client
**	Uses
**	Used By
**	Revisions
******************************************************************************************************************************/
-- Drop Function clearing_house.fn_clearinghouse_review_dataset_abundance_values_client_data(int, int)
-- Select * From clearing_house.fn_clearinghouse_review_dataset_abundance_values_client_data(2, 140)
Create Or Replace Function clearing_house.fn_clearinghouse_review_dataset_abundance_values_client_data(int, int)
Returns Table (

	local_db_id					int,
	public_db_id 				int,

	abundance_id 				int,
	physical_sample_id 			int,
	taxon_id 					int,

    genus_name					character varying,
    species						character varying,
    sample_name					character varying,
    author_name					character varying,

    element_name				text,
    modification_type_name		text,
    identification_level_name	text,

    abundance					int,
    public_abundance			int,

	entity_type_id				int

) As $$
Declare
    entity_type_id int;
    public_ds_id int;

Begin

    entity_type_id := clearing_house.fn_get_entity_type_for('tbl_abundances');

	Select x.public_db_id Into public_ds_id
	From clearing_house.view_datasets x
	Where x.local_db_id = -$2;

	Return Query

		Select

			LDB.local_db_id						               			As local_db_id,
			LDB.public_db_id						               		As public_db_id,

			LDB.abundance_id					               			As abundance_id,
			LDB.physical_sample_id				               			As physical_sample_id,
			LDB.taxon_id						               			As taxon_id,

			LDB.genus_name												As genus_name,
			LDB.species													As species,
			LDB.sample_name												As sample_name,
			LDB.author_name												As author_name,
			LDB.element_name											As element_name,
			LDB.modification_type_name									As modification_type_name,
			LDB.identification_level_name								As identification_level_name,

			LDB.abundance												As abundance,

			RDB.abundance												As public_abundance,

			entity_type_id												As entity_type_id
		-- Select LDB.*
		From clearing_house.view_clearinghouse_dataset_abundances LDB

		Left Join clearing_house.view_dataset_abundances RDB
		  On RDB.dataset_id =  LDB.public_dataset_id
		 And RDB.taxon_id = LDB.public_taxon_id
		 And RDB.abundance_id = LDB.public_db_id
		 And RDB.physical_sample_id = LDB.public_physical_sample_id

		Where LDB.source_id = 1
		  And LDB.submission_id = $1
		  And LDB.local_dataset_id = -$2;

End $$ Language plpgsql;


CREATE OR REPLACE FUNCTION clearing_house.fn_clearinghouse_review_dataset_references_client_data(
    IN integer,
    IN integer)
RETURNS TABLE(
      local_db_id integer,
      full_reference text,
      public_db_id integer,
      public_reference text,
      date_updated text,
      entity_type_id integer
) AS
$BODY$
Declare
    entity_type_id int;
Begin
    entity_type_id := clearing_house.fn_get_entity_type_for('tbl_datasets');
	Return Query
        Select
                LDB.dataset_id                       		As local_db_id,
                LDB.reference                           	As reference,
                LDB.public_db_id                        	As public_db_id,
                RDB.reference                           	As public_reference,
                to_char(LDB.date_updated,'YYYY-MM-DD')		As date_updated,
                entity_type_id              			As entity_type_id
            From (
                Select
                    d.source_id				    As source_id,
                    d.submission_id				As submission_id,
                    d.dataset_id				As dataset_id,
                    b.biblio_id 				As local_db_id,
                    b.public_db_id				As public_db_id,
                    b.full_reference		 	As reference,
                    b.date_updated				As date_updated
                From clearing_house.view_datasets d
                Join clearing_house.view_biblio b
                  On b.merged_db_id = d.biblio_id
                 And b.submission_id In (0, d.submission_id)
            ) As LDB Left Join (
                Select b.biblio_id				As biblio_id,
                    b.full_reference			As reference
                From public.tbl_biblio b
            ) As RDB
              On RDB.biblio_id = LDB.public_db_id
            Where LDB.source_id = 1
              And LDB.submission_id = 1
              And LDB.dataset_id = $1;

End $BODY$
LANGUAGE plpgsql VOLATILE
;
﻿
/*****************************************************************************************************************************
**  Function    fn_clearinghouse_review_sample
**	Who			Roger Mähler
**	When		2013-11-14
**	What		Returns sample data used by client
**	Uses
**	Used By
**	Revisions
******************************************************************************************************************************/
-- Drop Function clearing_house.fn_clearinghouse_review_sample(int, int)
-- Select * From clearing_house.fn_clearinghouse_review_sample(2, 2453)
Create Or Replace Function clearing_house.fn_clearinghouse_review_sample(int, int)
Returns Table (

    local_db_id					int,
    date_sampled                character varying(255),
    sample_name                 character varying(50),
    sample_name_type            character varying(50),
    type_name                   character varying(40),

    public_db_id				int,
    public_date_sampled         character varying(255),
    public_sample_name          character varying(50),
    public_sample_name_type     character varying(50),
    public_type_name            character varying(40),

    entity_type_id				int

) As $$

Declare
    entity_type_id int;

Begin

    entity_type_id := clearing_house.fn_get_entity_type_for('tbl_physical_samples');

    Return Query

        With sample (submission_id, source_id, local_db_id, public_db_id, merged_db_id, date_sampled, sample_name, sample_name_type, sample_type) As (
            Select  s.submission_id         As submission_id,
                    s.source_id             As source_id,
                    s.local_db_id           As local_db_id,
                    s.public_db_id          As public_db_id,
                    s.merged_db_id          As merged_db_id,
                    s.date_sampled          As date_sampled,
                    s.sample_name           As sample_name,
                    r.alt_ref_type          As sample_type_type,
                    n.type_name             As sample_type
            From clearing_house.view_physical_samples s
            Left Join clearing_house.view_alt_ref_types r
              On r.merged_db_id = s.alt_ref_type_id
             And r.submission_id In (0, s.submission_id)
            Join clearing_house.view_sample_types n
              On n.merged_db_id = s.sample_type_id
             And n.submission_id In (0, s.submission_id)
        )
            Select

                LDB.local_db_id						As local_db_id,
                LDB.date_sampled                    As date_sampled,
                LDB.sample_name                     As sample_name,
                LDB.sample_name_type				As sample_name_type,
                LDB.sample_type                     As sample_type,

                LDB.public_db_id					As public_db_id,
                RDB.date_sampled                    As public_date_sampled,
                RDB.sample_name                     As public_sample_name,
                RDB.sample_name_type				As public_sample_name_type,
                RDB.sample_type                     As public_sample_type,

                entity_type_id

            From sample LDB
            Left Join sample RDB
              On RDB.source_id = 2
             And RDB.public_db_id = LDB.public_db_id
            Where LDB.source_id = 1
              And LDB.submission_id = $1
              And LDB.local_db_id = -$2;

End $$ Language plpgsql;

/*****************************************************************************************************************************
**	Function	fn_clearinghouse_review_sample_alternative_names
**	Who			Roger Mähler
**	When		2013-11-13
**	What		Returns sample group lithology review data used by client
**	Uses
**	Used By
**	Revisions

Select s.merged_db_id,
       a.alt_ref,
       t.alt_ref_type
From clearing_house.view_physical_samples s
Join clearing_house.view_sample_alt_refs a
  On a.physical_sample_id = s.merged_db_id
 And a.submission_id in (0, s.submission_id)
Join clearing_house.view_alt_ref_types t
  On t.merged_db_id = a.alt_ref_type_id
 And t.submission_id in (0, s.submission_id)

******************************************************************************************************************************/
-- Select * From clearing_house.tbl_sites
-- Drop Function clearing_house.fn_clearinghouse_review_sample_alternative_names(int, int)
-- Select * From clearing_house.fn_clearinghouse_review_sample_alternative_names(2,2220)
Create Or Replace Function clearing_house.fn_clearinghouse_review_sample_alternative_names(int, int)
Returns Table (

    local_db_id				int,
    alt_ref                 character varying(40),
    alt_ref_type			character varying(50),

    public_db_id			int,
    public_alt_ref          character varying(40),
    public_alt_ref_type		character varying(50),

    date_updated            text,
    entity_type_id			int

) As $$

Declare
    entity_type_id int;

Begin

    entity_type_id := clearing_house.fn_get_entity_type_for('tbl_sample_alt_refs');

    Return Query

            Select

                LDB.local_db_id		                    As local_db_id,

                LDB.alt_ref                      		As alt_ref,
                LDB.alt_ref_type						As alt_ref_type,

                LDB.public_db_id                        As public_db_id,
                RDB.alt_ref                      		As public_alt_ref,
                RDB.alt_ref_type 						As public_alt_ref_type,

                to_char(LDB.date_updated,'YYYY-MM-DD')	As date_updated,
                entity_type_id                 			As entity_type_id

            From (
                Select s.submission_id					As submission_id,
                       s.source_id						As source_id,
                       s.merged_db_id					As physical_sample_id,
                       a.local_db_id					As local_db_id,
                       a.public_db_id					As public_db_id,
                       a.merged_db_id					As merged_db_id,
                       a.alt_ref                        As alt_ref,
                       t.alt_ref_type                   As alt_ref_type,
                       a.date_updated					As date_updated
                From clearing_house.view_physical_samples s
                Join clearing_house.view_sample_alt_refs a
                  On a.physical_sample_id = s.merged_db_id
                 And a.submission_id in (0, s.submission_id)
                Join clearing_house.view_alt_ref_types t
                  On t.merged_db_id = a.alt_ref_type_id
                 And t.submission_id in (0, s.submission_id)
            ) As LDB Left Join (
                Select a.alt_ref_type_id    			As alt_ref_type_id,
                       a.alt_ref                        As alt_ref,
                       t.alt_ref_type                   As alt_ref_type
                From public.tbl_sample_alt_refs a
                Join public.tbl_alt_ref_types t
                  On t.alt_ref_type_id = a.alt_ref_type_id
            ) As RDB
              On RDB.alt_ref_type_id = LDB.public_db_id
            Where LDB.source_id = 1
              And LDB.submission_id = $1
              And LDB.physical_sample_id = -$2;

End $$ Language plpgsql;

/*****************************************************************************************************************************
**	Function	fn_clearinghouse_review_sample_features
**	Who			Roger Mähler
**	When		2013-11-13
**	What		Returns sample gourp reference review data used by client
**	Uses
**	Used By
**	Revisions

Select s.merged_db_id,
       f.feature_name,
       f.feature_description,
       t.feature_type_name
From clearing_house.view_physical_samples s
Join clearing_house.view_physical_sample_features fs
  On fs.physical_sample_id = s.merged_db_id
 And fs.submission_id in (0, s.submission_id)
Join clearing_house.view_features f
  On f.merged_db_id = fs.feature_id
 And f.submission_id in (0, s.submission_id)
Join clearing_house.view_feature_types t
  On t.merged_db_id = f.feature_type_id
 And t.submission_id in (0, s.submission_id)

******************************************************************************************************************************/
-- Drop Function clearing_house.fn_clearinghouse_review_sample_features(int, int)
-- Select * From clearing_house.fn_clearinghouse_review_sample_features(2, 3931)
Create Or Replace Function clearing_house.fn_clearinghouse_review_sample_features(int, int)
Returns Table (

    local_db_id                 int,
    feature_name                character varying(255),
    feature_description         text,
    feature_type_name           character varying(128),

    public_db_id int,
    public_feature_name         character varying(255),
    public_feature_description  text,
    public_feature_type_name    character varying(128),

    date_updated text,
    entity_type_id int

) As $$
Declare
    sample_group_references_entity_type_id int;
Begin

    sample_group_references_entity_type_id := clearing_house.fn_get_entity_type_for('tbl_physical_sample_features');

    Return Query

        Select
            LDB.local_db_id                             As local_db_id,
            LDB.feature_name                            As feature_name,
            LDB.feature_description                     As feature_description,
            LDB.feature_type_name                       As feature_type_name,
            LDB.public_db_id                            As public_db_id,
            RDB.feature_name                            As public_feature_name,
            RDB.feature_description                     As public_feature_description,
            RDB.feature_type_name                       As public_feature_type_name,
            to_char(LDB.date_updated,'YYYY-MM-DD')		As date_updated,
            sample_group_references_entity_type_id		As entity_type_id
        From (
            Select	s.source_id                         As source_id,
                    s.submission_id                     As submission_id,
                    s.merged_db_id                      As physical_sample_id,
                    fs.local_db_id						As local_db_id,
                    fs.public_db_id						As public_db_id,
                    fs.merged_db_id						As merged_db_id,
                    f.feature_name						As feature_name,
                    f.feature_description				As feature_description,
                    t.feature_type_name					As feature_type_name,
                    fs.date_updated                     As date_updated
            From clearing_house.view_physical_samples s
            Join clearing_house.view_physical_sample_features fs
              On fs.physical_sample_id = s.merged_db_id
             And fs.submission_id in (0, s.submission_id)
            Join clearing_house.view_features f
              On f.merged_db_id = fs.feature_id
             And f.submission_id in (0, s.submission_id)
            Join clearing_house.view_feature_types t
              On t.merged_db_id = f.feature_type_id
             And t.submission_id in (0, s.submission_id)
        ) As LDB Left Join (
            Select	fs.feature_id						As feature_id,
                    f.feature_name						As feature_name,
                    f.feature_description				As feature_description,
                    t.feature_type_name					As feature_type_name
            From public.tbl_physical_sample_features fs
            Join public.tbl_features f
              On f.feature_id = fs.feature_id
            Join public.tbl_feature_types t
              On t.feature_type_id = f.feature_type_id
        ) As RDB
          On RDB.feature_id = LDB.public_db_id
        Where LDB.source_id = 1
          And LDB.submission_id = $1
          And LDB.physical_sample_id = -$2;

End $$ Language plpgsql;

/*****************************************************************************************************************************
**	Function	fn_clearinghouse_review_sample_notes
**	Who			Roger Mähler
**	When		2013-11-13
**	What		Returns sample note review data used by client
**	Uses
**	Used By
**	Revisions

Select  n.merged_db_id,
        n.note_type                         As note_type,
        n.note                              As note,
        n.date_updated						As date_updated
From clearing_house.view_physical_samples s
Join clearing_house.view_sample_notes n
  On n.physical_sample_id = s.merged_db_id
 And n.submission_id in (0, s.submission_id)

******************************************************************************************************************************/
-- Drop Function clearing_house.fn_clearinghouse_review_sample_notes(int, int)
-- Select * From clearing_house.fn_clearinghouse_review_sample_notes(2, 2626)
Create Or Replace Function clearing_house.fn_clearinghouse_review_sample_notes(int, int)
Returns Table (

    local_db_id			int,
    note				text,
    note_type			character varying,

    public_db_id		int,
    public_note			text,
    public_note_type	character varying,

    date_updated		text,
    entity_type_id		int

) As $$
Declare
    entity_type_id int;
Begin

    entity_type_id := clearing_house.fn_get_entity_type_for('tbl_sample_notes');

    Return Query

        Select
            LDB.local_db_id					            As local_db_id,
            LDB.note                              		As note,
            LDB.note_type                          		As note_type,
            LDB.public_db_id                            As public_db_id,
            RDB.note                               		As public_note,
            RDB.note_type                          		As note_type,
            to_char(LDB.date_updated,'YYYY-MM-DD')		As date_updated,
            entity_type_id                              As entity_type_id
        From (
            Select	s.source_id                         As source_id,
                    s.submission_id                     As submission_id,
                    s.local_db_id						As physical_sample_id,
                    n.local_db_id						As local_db_id,
                    n.public_db_id						As public_db_id,
                    n.merged_db_id						As merged_db_id,
                    n.note								As note,
                    n.note_type							As note_type,
                    n.date_updated						As date_updated
            From clearing_house.view_physical_samples s
            Join clearing_house.view_sample_notes n
              On n.physical_sample_id = s.merged_db_id
             And n.submission_id in (0, s.submission_id)
        ) As LDB Left Join (
            Select	n.sample_note_id                    As sample_note_id,
                    n.note								As note,
                    n.note_type							As note_type
            From public.tbl_sample_notes n
        ) As RDB
          On RDB.sample_note_id = LDB.public_db_id
        Where LDB.source_id = 1
          And LDB.submission_id = $1
          And LDB.physical_sample_id = -$2;

End $$ Language plpgsql;

/*****************************************************************************************************************************
**	Function	fn_clearinghouse_review_sample_dimensions
**	Who			Roger Mähler
**	When		2013-11-13
**	What		Returns sample dimension review data used by client
**	Uses
**	Used By
**	Revisions

Select d.merged_db_id as sample_dimension_id,
       d.dimension_value,
       Coalesce(t.dimension_abbrev, t.dimension_name, '') as dimension_name,
       m.method_name
From clearing_house.view_physical_samples s
Join clearing_house.view_sample_dimensions d
  On d.physical_sample_id = s.merged_db_id
 And d.submission_id in (0, s.submission_id)
Join clearing_house.view_dimensions t
  On t.merged_db_id = d.dimension_id
 And d.submission_id in (0, s.submission_id)
Join clearing_house.view_methods m
  On m.merged_db_id = d.method_id
 And m.submission_id in (0, s.submission_id)

******************************************************************************************************************************/
-- Drop Function clearing_house.fn_clearinghouse_review_sample_dimensions(int, int)
-- Select * From clearing_house.fn_clearinghouse_review_sample_dimensions(2, 2508)
Create Or Replace Function clearing_house.fn_clearinghouse_review_sample_dimensions(int, int)
Returns Table (

    local_db_id						int,
    dimension_value					numeric(20,10),
    dimension_name					character varying(50),
    method_name                     character varying(50),

    public_db_id					int,
    public_dimension_value			numeric(20,10),
    public_dimension_name			character varying(50),
    public_method_name              character varying(50),

    date_updated					text,
    entity_type_id					int

) As $$
Declare
    entity_type_id int;
Begin

    entity_type_id := clearing_house.fn_get_entity_type_for('tbl_sample_dimensions');

    Return Query

        Select
            LDB.local_db_id				               					As local_db_id,
            LDB.dimension_value                         				As dimension_value,
            LDB.dimension_name                         					As dimension_name,
            LDB.method_name                         					As method_name,
            LDB.public_db_id				            				As public_db_id,
            RDB.dimension_value                         				As public_dimension_value,
            RDB.dimension_name                         					As public_dimension_name,
            RDB.method_name                         					As public_method_name,
            to_char(LDB.date_updated,'YYYY-MM-DD')						As date_updated,
            entity_type_id												As entity_type_id
        From (
            Select	s.source_id                                         As source_id,
                    s.submission_id                                     As submission_id,
                    s.local_db_id										As physical_sample_id,
                    sd.local_db_id 										As local_db_id,
                    sd.public_db_id 									As public_db_id,
                    sd.merged_db_id 									As merged_db_id,
                    sd.dimension_value                                  As dimension_value,
                    Coalesce(t.dimension_abbrev, t.dimension_name, '')  As dimension_name,
                    m.method_name                                       As method_name,
                    sd.date_updated                                     As date_updated
            From clearing_house.view_physical_samples s
            Join clearing_house.view_sample_dimensions sd
              On sd.physical_sample_id = s.merged_db_id
             And sd.submission_id in (0, s.submission_id)
            Join clearing_house.view_dimensions t
              On t.merged_db_id = sd.dimension_id
             And t.submission_id in (0, s.submission_id)
            Join clearing_house.view_methods m
              On m.merged_db_id = sd.method_id
             And m.submission_id in (0, s.submission_id)
        ) As LDB Left Join (
            Select	sd.sample_dimension_id 								As sample_dimension_id,
                    sd.dimension_value                                  As dimension_value,
                    Coalesce(t.dimension_abbrev, t.dimension_name, '')  As dimension_name,
                    m.method_name                                       As method_name
            From public.tbl_sample_dimensions sd
            Join public.tbl_dimensions t
              On t.dimension_id = sd.dimension_id
            Join public.tbl_methods m
              On m.method_id = sd.method_id
          ) As RDB
          On RDB.sample_dimension_id = LDB.public_db_id
        Where LDB.source_id = 1
          And LDB.submission_id = $1
          And LDB.physical_sample_id = -$2;

End $$ Language plpgsql;


/*****************************************************************************************************************************
**	Function	fn_clearinghouse_review_sample_descriptions
**	Who			Roger Mähler
**	When		2013-11-13
**	What		Returns sample descriptions review data used by client
**	Uses
**	Used By
**	Revisions

Select s.merged_db_id,
       d.description,
       t.type_name,
       t.type_description
From clearing_house.view_physical_samples s
Join clearing_house.view_sample_descriptions d
  On d.sample_description_id = s.merged_db_id
 And d.submission_id in (0, s.submission_id)
Join clearing_house.view_sample_description_types t
  On t.merged_db_id = d.sample_description_type_id
 And t.submission_id in (0, s.submission_id)

******************************************************************************************************************************/
-- Drop Function clearing_house.fn_clearinghouse_review_sample_descriptions(int, int)
-- Select * From clearing_house.fn_clearinghouse_review_sample_descriptions(2, -40)
Create Or Replace Function clearing_house.fn_clearinghouse_review_sample_descriptions(int, int)
Returns Table (

    local_db_id					int,
    type_name					character varying(255),
    type_description			text,

    public_db_id 				int,
    public_type_name			character varying(255),
    public_type_description		text,

    date_updated				text,
    entity_type_id				int

) As $$
Declare
    entity_type_id int;
Begin

    entity_type_id := clearing_house.fn_get_entity_type_for('tbl_sample_descriptions');

    Return Query

        Select
            LDB.local_db_id				               					As local_db_id,

            LDB.type_name                         						As type_name,
            LDB.type_description                       					As type_description,

            LDB.public_db_id				            				As public_db_id,

            RDB.type_name                         						As public_type_name,
            RDB.type_description                       					As public_type_description,

            to_char(LDB.date_updated,'YYYY-MM-DD')						As date_updated,
            entity_type_id												As entity_type_id

        From (
            Select	s.source_id                                         As source_id,
                    s.submission_id                                     As submission_id,
                    s.local_db_id										As physical_sample_id,
                    sd.local_db_id										As local_db_id,
                    sd.public_db_id										As public_db_id,
                    sd.merged_db_id										As merged_db_id,
                    sd.description                                      As description,
                    t.type_name                                         As type_name,
                    t.type_description                                  As type_description,
                    sd.date_updated                                     As date_updated
            From clearing_house.view_physical_samples s
            Join clearing_house.view_sample_descriptions sd
              On sd.sample_description_id = s.merged_db_id
             And sd.submission_id in (0, s.submission_id)
            Join clearing_house.view_sample_description_types t
              On t.merged_db_id = sd.sample_description_type_id
             And t.submission_id in (0, s.submission_id)
        ) As LDB Left Join (
            Select	sd.sample_description_id							As sample_description_id,
                    sd.description                                      As description,
                    t.type_name                                         As type_name,
                    t.type_description                                  As type_description
            From public.tbl_sample_descriptions sd
            Join public.tbl_sample_description_types t
              On t.sample_description_type_id = sd.sample_description_type_id
          ) As RDB
          On RDB.sample_description_id = LDB.public_db_id
        Where LDB.source_id = 1
          And LDB.submission_id = $1
          And LDB.physical_sample_id = -$2;

End $$ Language plpgsql;


/*****************************************************************************************************************************
**	Function	fn_clearinghouse_review_sample_horizons
**	Who			Roger Mähler
**	When		2013-11-13
**	What		Returns sample horizons review data used by client
**	Uses
**	Used By
**	Revisions


Select  sh.merged_db_id,
        h.merged_db_id,
        h.horizon_name,
        h.description,
        m.method_name
From clearing_house.view_physical_samples s
Join clearing_house.view_sample_horizons sh
  On sh.physical_sample_id = s.merged_db_id
 And sh.submission_id in (0, s.submission_id)
Join clearing_house.view_horizons h
  On h.merged_db_id = sh.horizon_id
 And h.submission_id in (0, s.submission_id)
Join clearing_house.view_methods m
  On m.merged_db_id = h.method_id
 And m.submission_id in (0, s.submission_id)


******************************************************************************************************************************/
-- Drop Function clearing_house.fn_clearinghouse_review_sample_horizons(int, int)
-- Select * From clearing_house.fn_clearinghouse_review_sample_horizons(2, 2519)
Create Or Replace Function clearing_house.fn_clearinghouse_review_sample_horizons(int, int)
Returns Table (

    local_db_id						int,
    horizon_name                    character varying(15),
    description                     text,
    method_name                     character varying(50),

    public_db_id 					int,
    public_horizon_name             character varying(15),
    public_description              text,
    public_method_name              character varying(50),

    date_updated                    text,
    entity_type_id					int

) As $$
Declare
    entity_type_id int;
Begin
    -- Entity in focus should perhaps be tbl_samples instead. In such case return ids from h (and join LDB & RDB on horizon id)
    entity_type_id := clearing_house.fn_get_entity_type_for('tbl_sample_horizons');

    Return Query

        Select
            LDB.local_db_id				               	As local_db_id, --> use horizon_id instead?
            LDB.horizon_name                            As horizon_name,
            LDB.description                             As description,
            LDB.method_name                       		As method_name,
            LDB.public_db_id				            As public_db_id,
            RDB.horizon_name                            As public_horizon_name,
            RDB.description                             As public_description,
            RDB.method_name                       		As public_method_name,
            to_char(LDB.date_updated,'YYYY-MM-DD')		As date_updated,
            entity_type_id								As entity_type_id
        From (
            Select	s.source_id                         As source_id,
                    s.submission_id                     As submission_id,
                    s.local_db_id						As physical_sample_id,
                    sh.local_db_id						As local_db_id,
                    sh.public_db_id						As public_db_id,
                    sh.merged_db_id						As merged_db_id,
                    --h.merged_db_id                    As horizon_id,/* alternative review entity */
                    h.horizon_name                      As horizon_name,
                    h.description                       As description,
                    m.method_name                       As method_name,
                    sh.date_updated                     As date_updated
            From clearing_house.view_physical_samples s
            Join clearing_house.view_sample_horizons sh
              On sh.physical_sample_id = s.merged_db_id
             And sh.submission_id in (0, s.submission_id)
            Join clearing_house.view_horizons h
              On h.merged_db_id = sh.horizon_id
             And h.submission_id in (0, s.submission_id)
            Join clearing_house.view_methods m
              On m.merged_db_id = h.method_id
             And m.submission_id in (0, s.submission_id)
            Where 1 = 1
        ) As LDB Left Join (
            Select	sh.sample_horizon_id				As sample_horizon_id,
                    h.horizon_name                      As horizon_name,
                    h.description                       As description,
                    m.method_name                       As method_name
            From public.tbl_sample_horizons sh
            Join public.tbl_horizons h
              On h.horizon_id = sh.horizon_id
            Join public.tbl_methods m
              On m.method_id = h.method_id
        ) As RDB
          On RDB.sample_horizon_id = LDB.public_db_id
        Where LDB.source_id = 1
          And LDB.submission_id = $1
          And LDB.physical_sample_id = -$2;

End $$ Language plpgsql;

/*****************************************************************************************************************************
**	Function	fn_clearinghouse_review_sample_colours
**	Who			Roger Mähler
**	When		2013-11-13
**	What		Returns sample colours review data used by client
**	Uses
**	Used By
**	Revisions


Select  sc.merged_db_id,
        c.merged_db_id,
        c.colour_name,
        c.rgb,          -- Bör visas i visas
        m.method_name
From clearing_house.view_physical_samples s
Join clearing_house.view_sample_colours sc
  On sc.physical_sample_id = s.merged_db_id
 And sc.submission_id in (0, s.submission_id)
Join clearing_house.view_colours c
  On c.merged_db_id = sc.colour_id
 And c.submission_id in (0, s.submission_id)
Join clearing_house.view_methods m
  On m.merged_db_id = c.method_id
 And m.submission_id in (0, s.submission_id)


******************************************************************************************************************************/
-- Drop Function clearing_house.fn_clearinghouse_review_sample_colours(int, int)
-- Select * From clearing_house.fn_clearinghouse_review_sample_colours(2, -40)
Create Or Replace Function clearing_house.fn_clearinghouse_review_sample_colours(int, int)
Returns Table (

    local_db_id						int,
    colour_name                     character varying(30),
    rgb                             integer,
    method_name                     character varying(50),

    public_db_id 					int,
    public_colour_name              character varying(30),
    public_rgb                      integer,
    public_method_name              character varying(50),

    date_updated                    text,
    entity_type_id					int

) As $$
Declare
    entity_type_id int;
Begin

    entity_type_id := clearing_house.fn_get_entity_type_for('tbl_colours');

    Return Query

        Select
            LDB.local_db_id				               	As local_db_id, /* Alt: Use colour_id instead */
            LDB.colour_name                             As colour_name,
            LDB.rgb                                     As rgb,
            LDB.method_name                       		As method_name,

            LDB.public_db_id				            As public_db_id,
            RDB.colour_name                             As public_colour_name,
            RDB.rgb                                     As public_rgb,
            RDB.method_name                       		As public_method_name,

            to_char(LDB.date_updated,'YYYY-MM-DD')		As date_updated,
            entity_type_id								As entity_type_id

        From (
            Select	s.source_id                         As source_id,
                    s.submission_id                     As submission_id,
                    s.local_db_id						As physical_sample_id,
                    sc.local_db_id						As local_db_id,
                    sc.public_db_id						As public_db_id,
                    sc.merged_db_id						As merged_db_id,
                    --c.merged_db_id                    As colour_id, /* alternative review entity */
                    c.colour_name                       As colour_name,
                    c.rgb                               As rgb,
                    m.method_name                       As method_name,
                    sc.date_updated                     As date_updated
            From clearing_house.view_physical_samples s
            Join clearing_house.view_sample_colours sc
              On sc.physical_sample_id = s.merged_db_id
             And sc.submission_id in (0, s.submission_id)
            Join clearing_house.view_colours c
              On c.merged_db_id = sc.colour_id
             And c.submission_id in (0, s.submission_id)
            Join clearing_house.view_methods m
              On m.merged_db_id = c.method_id
             And m.submission_id in (0, s.submission_id)
        ) As LDB Left Join (
            Select	sc.sample_colour_id					As sample_colour_id,
                    c.colour_id                         As colour_id, /* alternative review entity */
                    c.colour_name                       As colour_name,
                    c.rgb                               As rgb,
                    m.method_name                       As method_name
            From public.tbl_sample_colours sc
            Join public.tbl_colours c
              On c.colour_id = sc.colour_id
            Join public.tbl_methods m
              On m.method_id = c.method_id
        ) As RDB
          On RDB.sample_colour_id = LDB.public_db_id
        Where LDB.source_id = 1
          And LDB.submission_id = $1
          And LDB.physical_sample_id = -$2;

End $$ Language plpgsql;

/*****************************************************************************************************************************
**	Function	fn_clearinghouse_review_sample_images
**	Who			Roger Mähler
**	When		2013-11-13
**	What		Returns sample images review data used by client
**	Uses
**	Used By
**	Revisions


Select  si.merged_db_id,
        si.image_name,
        si.description,
        it.image_type
From clearing_house.view_physical_samples s
Join clearing_house.view_sample_images si
  On si.physical_sample_id = s.merged_db_id
 And si.submission_id in (0, s.submission_id)
Join clearing_house.view_image_types it
  On it.merged_db_id = si.image_type_id
 And it.submission_id in (0, s.submission_id)


******************************************************************************************************************************/
-- Drop Function clearing_house.fn_clearinghouse_review_sample_images(int, int)
-- Select * From clearing_house.fn_clearinghouse_review_sample_images(2, 2453)
Create Or Replace Function clearing_house.fn_clearinghouse_review_sample_images(int, int)
Returns Table (

    local_db_id						int,
    image_name                      character varying(80),
    description                     text,
    image_type						character varying(40),

    public_db_id 					int,
    public_image_name               character varying(80),
    public_description              text,
    public_image_type				character varying(40),

    date_updated                    text,
    entity_type_id					int

) As $$
Declare
    entity_type_id int;
Begin

    entity_type_id := clearing_house.fn_get_entity_type_for('tbl_sample_images');

    Return Query

        Select
            LDB.local_db_id				               	As local_db_id,

            LDB.image_name                              As image_name,
            LDB.description                             As description,
            LDB.image_type                       		As image_type,

            LDB.public_db_id				            As public_db_id,

            RDB.image_name                              As public_image_name,
            RDB.description                             As public_description,
            RDB.image_type                       		As public_image_type,

            to_char(LDB.date_updated,'YYYY-MM-DD')		As date_updated,
            entity_type_id								As entity_type_id

        From (
            Select	s.source_id                         As source_id,
                    s.submission_id                     As submission_id,
                    s.local_db_id						As physical_sample_id,
                    si.local_db_id						As local_db_id,
                    si.public_db_id						As public_db_id,
                    si.merged_db_id						As merged_db_id,
                    si.image_name                       As image_name,
                    si.description                      As description,
                    it.image_type                       As image_type,
                    si.date_updated                     As date_updated
            From clearing_house.view_physical_samples s
            Join clearing_house.view_sample_images si
              On si.physical_sample_id = s.merged_db_id
             And si.submission_id in (0, s.submission_id)
            Join clearing_house.view_image_types it
              On it.merged_db_id = si.image_type_id
             And it.submission_id in (0, s.submission_id)
        ) As LDB Left Join (
            Select	si.sample_image_id					As sample_image_id,
                    si.image_name                       As image_name,
                    si.description                      As description,
                    it.image_type                       As image_type
            From public.tbl_sample_images si
            Join public.tbl_image_types it
              On it.image_type_id = si.image_type_id
        ) As RDB
          On RDB.sample_image_id = LDB.public_db_id
        Where LDB.source_id = 1
          And LDB.submission_id = $1
          And LDB.physical_sample_id = -$2;

End $$ Language plpgsql;

/*****************************************************************************************************************************
**	Function	fn_clearinghouse_review_sample_locations
**	Who			Roger Mähler
**	When		2013-11-07
**	What		Returns site locations used by client
**	Uses
**	Used By
**	Revisions


Select sl.merged_db_id,
       sl.location,
       t.location_type,
       t.description
From clearing_house.view_physical_samples s
Join clearing_house.view_sample_locations sl
  On sl.physical_sample_id = s.merged_db_id
 And sl.submission_id in (0, s.submission_id)
Join clearing_house.view_location_types t
  On t.merged_db_id = sl.sample_location_type_id
 And t.submission_id in (0, s.submission_id)

******************************************************************************************************************************/
-- Drop Function clearing_house.fn_clearinghouse_review_sample_locations(int, int)
-- Select * From clearing_house.fn_clearinghouse_review_sample_locations(2, 2453)
Create Or Replace Function clearing_house.fn_clearinghouse_review_sample_locations(int, int)
Returns Table (

    local_db_id                 int,
    location                    character varying(255),
    location_type               character varying(40),
    description                 text,

    public_db_id int,
    public_location             character varying(255),
    public_location_type        character varying(40),
    public_description          text,

    date_updated text,
    entity_type_id int

) As $$

Declare
    entity_type_id int;

Begin

    entity_type_id := clearing_house.fn_get_entity_type_for('tbl_sample_locations');

    Return Query

            Select

                LDB.local_db_id                   		As local_db_id,

                LDB.location                            As location,
                LDB.location_type                       As location_type,
                LDB.description                         As description,

                LDB.public_db_id                        As public_db_id,

                RDB.location                            As public_location,
                RDB.location_type                       As public_location_type,
                RDB.description                         As public_description,

                to_char(LDB.date_updated,'YYYY-MM-DD')	As date_updated,
                entity_type_id              			As entity_type_id

            From (
                Select	s.source_id                         As source_id,
                        s.submission_id                     As submission_id,
                        s.local_db_id						As physical_sample_id,
                        sl.local_db_id						As local_db_id,
                        sl.public_db_id						As public_db_id,
                        sl.merged_db_id						As merged_db_id,
                        sl.location                         As location,
                        t.location_type                     As location_type,
                        t.location_type_description         As description,
                        sl.date_updated						As date_updated
                From clearing_house.view_physical_samples s
                Join clearing_house.view_sample_locations sl
                  On sl.physical_sample_id = s.merged_db_id
                 And sl.submission_id in (0, s.submission_id)
                Join clearing_house.view_sample_location_types t
                  On t.merged_db_id = sl.sample_location_type_id
                 And t.submission_id in (0, s.submission_id)
            ) As LDB Left Join (
                Select	sl.sample_location_id				As sample_location_id,
                        sl.location                         As location,
                        t.location_type                     As location_type,
                        t.location_type_description         As description
                From public.tbl_sample_locations sl
                Join public.tbl_sample_location_types t
                  On t.sample_location_type_id = sl.sample_location_type_id
            ) As RDB
              On RDB.sample_location_id = LDB.public_db_id
            Where LDB.source_id = 1
              And LDB.submission_id = $1
              And LDB.physical_sample_id = -$2;

End $$ Language plpgsql;


-- drop function clearing_house.fn_clearinghouse_review_dendro_date_notes(integer, integer);
create or replace function clearing_house.fn_clearinghouse_review_sample_dendro_date_notes(p_submission_id integer, p_physical_sample_id integer)
returns table(
    local_db_id    integer,
    dendro_date_id integer,
    note           text,
    public_db_id   integer,
    public_note    text,
    date_updated   text,
    entity_type_id integer
) language 'plpgsql'
as $body$
declare
    entity_type_id int;
begin

    entity_type_id := clearing_house.fn_get_entity_type_for('tbl_dendro_date_notes');

    return query
        with submission_notes as (
            select	dd.source_id						as source_id,
                    dd.submission_id					as submission_id,
                    ps.local_db_id						As physical_sample_id,
                    dd.local_db_id						as dendro_date_id,
                    ddn.local_db_id						as local_db_id,
                    ddn.public_db_id					as public_db_id,
                    ddn.merged_db_id					as merged_db_id,
                    ddn.note							as note,
                    ddn.date_updated					as date_updated
            from clearing_house.view_dendro_dates dd
            join clearing_house.view_dendro_date_notes ddn
              on ddn.dendro_date_id = dd.merged_db_id
             and ddn.submission_id in (0, dd.submission_id)
            join clearing_house.view_analysis_entities ae
              on ae.merged_db_id = dd.analysis_entity_id
             and ae.submission_id in (9, dd.submission_id)
            join clearing_house.view_physical_samples ps
              on ps.merged_db_id = ae.physical_sample_id
             and ps.submission_id in (0, dd.submission_id)
        )
            select ldb.local_db_id					        as local_db_id,
                   ldb.dendro_date_id                       as dendro_date_id,
                   ldb.note                              	as note,
                   ldb.public_db_id                         as public_db_id,
                   rdb.note                              	as public_note,
                   to_char(ldb.date_updated,'yyyy-mm-dd')	as date_updated,
                   entity_type_id                  			as entity_type_id
            from submission_notes as ldb
            left join public.tbl_dendro_date_notes as rdb
              on rdb.dendro_date_note_id = ldb.public_db_id
            where ldb.source_id = 1
              and ldb.submission_id = p_submission_id
              and ldb.physical_sample_id = -p_physical_sample_id;

end
$body$;

-- drop function clearing_house.fn_clearinghouse_review_sample_dendro_dates(integer, integer);
create or replace function clearing_house.fn_clearinghouse_review_sample_dendro_dates(p_submission_id integer, p_physical_sample_id integer)
returns table(

    local_db_id integer,
    sample_name character varying,
    dating_type character varying,
    season_type character varying,
    date text,
    error_years_minus text,
    error_years_plus text,

    public_db_id integer,
    public_sample_name character varying,
    public_dating_type character varying,
    public_season_type character varying,
    public_date text,
    public_error_years_minus text,
    public_error_years_plus text,

    entity_type_id integer
) as
$body$
declare
    entity_type_id int;
begin
    entity_type_id := clearing_house.fn_get_entity_type_for('tbl_dendro_dates');

    return query

        select

            ldb.local_db_id				               						as dendro_date_id,
            ldb.sample_name                     							as sample_name,
            ldb.lookup_name													as dating_type,
            ldb.season_or_qualifier_type									as season_type,
            coalesce(ldb.uncertainty, '') ||
                coalesce(ldb.age_older || '-', '') ||
                coalesce(ldb.age_younger, '') ||' '|| ldb.age_type          as date,
            coalesce(ldb.error_uncertainty_type, '') || ' ' ||
                coalesce(ldb.error_minus, '') 	                            as error_years_minus,
            coalesce(ldb.error_uncertainty_type, '') || ' ' ||
                coalesce(ldb.error_plus, '') 	                            as error_years_plus,

            rdb.dendro_date_id												as public_db_id,
            rdb.sample_name                     							as public_sample_name,
            rdb.lookup_name													as public_dating_type,
            rdb.season_or_qualifier_type									as public_season_type,
            coalesce(rdb.uncertainty::text, '') ||
                coalesce(rdb.age_older || '-', '') ||
                coalesce(rdb.age_younger, '') ||' '|| rdb.age_type          as public_date,
            coalesce(rdb.error_uncertainty_type, '') || ' ' ||
                coalesce(rdb.error_minus, '')                               as public_error_years_minus,
            coalesce(rdb.error_uncertainty_type, '') || ' ' ||
                coalesce(rdb.error_plus, '') 	                            as public_error_years_plus,
            entity_type_id

        from (

            select	dd.source_id				 as source_id,
                    dd.submission_id			 as submission_id,
                    dd.local_db_id				 as local_db_id,
                    dd.public_db_id				 as public_db_id,
                    dd.merged_db_id				 as merged_db_id,
                    ps.local_db_id				 as physical_sample_id,
                    ps.sample_name				 as sample_name,
                    dl.name 					 as lookup_name,
                    soq.season_or_qualifier_type as season_or_qualifier_type,
                    du.uncertainty::text		 as uncertainty,
                    dd.age_older::text			 as age_older,
                    dd.age_younger::text		 as age_younger,
                    at.age_type					 as age_type,
                    eu.error_uncertainty_type	 as error_uncertainty_type,
                    dd.error_minus::text		 as error_minus,
                    dd.error_plus::text			 as error_plus,
                    dd.date_updated				 as date_updated

            from clearing_house.view_dendro_dates dd
            join clearing_house.view_analysis_entities ae
              on ae.merged_db_id = dd.analysis_entity_id
             and ae.submission_id in (0, dd.submission_id)
            left join clearing_house.view_age_types at
              on at.merged_db_id = dd.age_type_id
             and at.submission_id in (0, dd.submission_id)
            left join clearing_house.view_dating_uncertainty du
              on du.merged_db_id = dd.dating_uncertainty_id
             and du.submission_id in (0, dd.submission_id)
            left join clearing_house.view_error_uncertainties eu
              on eu.merged_db_id = dd.error_uncertainty_id
             and eu.submission_id in (0, dd.submission_id)
            left join clearing_house.view_season_or_qualifier soq
              on soq.merged_db_id = dd.season_or_qualifier_id
             and soq.submission_id in (0, dd.submission_id)
            left join clearing_house.view_dendro_lookup dl
              on dl.merged_db_id = dd.dendro_lookup_id
             and dl.submission_id in (0, dd.submission_id)
            join clearing_house.view_physical_samples ps
              on ps.merged_db_id = ae.physical_sample_id
             and ps.submission_id in (0, dd.submission_id)

        ) as ldb
        left join (
            select 	ps.physical_sample_id		 as physical_sample_id,
                    ps.sample_name				 as sample_name,
                    dd.dendro_date_id			 as dendro_date_id,
                    dl.name 					 as lookup_name,
                    soq.season_or_qualifier_type as season_or_qualifier_type,
                    du.uncertainty::text		 as uncertainty,
                    dd.age_older::text			 as age_older,
                    dd.age_younger::text		 as age_younger,
                    at.age_type				     as age_type,
                    eu.error_uncertainty_type	 as error_uncertainty_type,
                    dd.error_minus::text		 as error_minus,
                    dd.error_plus::text			 as error_plus,
                    dd.date_updated				 as date_updated

            from public.tbl_physical_samples ps
            join public.tbl_analysis_entities ae
                on ps.physical_sample_id = ae.physical_sample_id
            join public.tbl_dendro_dates dd
                on ae.analysis_entity_id = dd.analysis_entity_id
            join public.tbl_age_types at
                on at.age_type_id = dd.age_type_id
            left join public.tbl_dating_uncertainty du
                on du.dating_uncertainty_id = dd.dating_uncertainty_id
            left join public.tbl_error_uncertainties eu
                on eu.error_uncertainty_id = dd.error_uncertainty_id
            left join public.tbl_season_or_qualifier soq
                on soq.season_or_qualifier_id = dd.season_or_qualifier_id
            left join public.tbl_dendro_lookup dl
                on dl.dendro_lookup_id = dd.dendro_lookup_id
        ) as rdb
          on rdb.dendro_date_id = ldb.public_db_id

        where ldb.source_id = 1
          and ldb.submission_id = p_submission_id
          and ldb.physical_sample_id = -p_physical_sample_id;

end
$body$ language plpgsql;

-- drop function clearing_house.fn_clearinghouse_review_sample_positions_client_data(integer, integer);

create or replace function clearing_house.fn_clearinghouse_review_sample_positions(p_submission_id integer, p_physical_sample_id integer)
  returns table (

      local_db_id integer,
      sample_position text,
      position_accuracy numeric(20,10),
      method_name character varying,

      public_db_id integer,
      public_sample_position text,
      public_position_accuracy numeric(20,10),
      public_method_name character varying,

      entity_type_id integer
) as
$body$
declare
    entity_type_id int;
begin

    entity_type_id := clearing_house.fn_get_entity_type_for('tbl_sample_coordinates');

    return query

        select
            ldb.local_db_id				               	as local_db_id,
            coalesce(ldb.dimension_name, '') || ' ' ||
                coalesce(ldb.measurement, '')           as sample_position,
            ldb.accuracy                       		    as position_accuracy,
            ldb.method_name                       		as method_name,

            ldb.public_db_id				            as public_db_id,
            coalesce(rdb.dimension_name, '') || ' '||
                coalesce(rdb.measurement, '')           as public_sample_position,
            rdb.accuracy                       		    as public_position_accuracy,
            rdb.method_name                       		as public_method_name,
            entity_type_id						        as entity_type_id
        from (

            select	ps.source_id						as source_id,
                    ps.submission_id					as submission_id,
                    ps.local_db_id						as physical_sample_id,
                    d.local_db_id						as local_db_id,
                    d.public_db_id						as public_db_id,
                    d.merged_db_id						as merged_db_id,
                    c.measurement::text 				as measurement,
                    c.accuracy						    as accuracy,
                    m.method_name						as method_name,
                    d.dimension_name::text				as dimension_name
            from clearing_house.view_physical_samples ps
            join clearing_house.view_sample_coordinates c
              on c.physical_sample_id = ps.merged_db_id
             and c.submission_id in (0, ps.submission_id)
            join clearing_house.view_coordinate_method_dimensions md
              on md.merged_db_id = c.coordinate_method_dimension_id
             and md.submission_id in (0, ps.submission_id)
            join clearing_house.view_methods m
              on m.merged_db_id = md.method_id
             and m.submission_id in (0, ps.submission_id)
            join clearing_house.view_dimensions d
              on d.merged_db_id = md.dimension_id
             and d.submission_id in (0, ps.submission_id)

        ) as ldb left join (

            select	c.sample_coordinate_id		as sample_coordinate_id,
                    c.measurement::text			as measurement,
                    c.accuracy					as accuracy,
                    m.method_name				as method_name,
                    d.dimension_name::text		as dimension_name
            from public.tbl_sample_coordinates c
            join public.tbl_coordinate_method_dimensions md
              on md.coordinate_method_dimension_id = c.coordinate_method_dimension_id
            join public.tbl_methods m
              on m.method_id = md.method_id
            join public.tbl_dimensions d
              on d.dimension_id = md.dimension_id

        ) as rdb
          on rdb.sample_coordinate_id = ldb.public_db_id
        where ldb.source_id = 1
          and ldb.submission_id = p_submission_id
          and ldb.physical_sample_id = -p_physical_sample_id;

end $body$
  language plpgsql;﻿/*****************************************************************************************************************************
**	Function	fn_clearinghouse_review_sample_group_client_data
**	Who			Roger Mähler
**	When		2013-11-07
**	What		Returns site data used by client
**	Uses
**	Used By
**	Revisions
******************************************************************************************************************************/
-- Drop Function clearing_house.fn_clearinghouse_review_sample_group_client_data(int, int)
-- Select * From clearing_house.fn_clearinghouse_review_sample_group_client_data(1, -2024)
Create Or Replace Function clearing_house.fn_clearinghouse_review_sample_group_client_data(int, int)
Returns Table (

	local_db_id					int,
	sample_group_name			character varying(100),
	sampling_method				character varying(50),
	sampling_context			character varying(40),

	public_db_id				int,
	public_sample_group_name	character varying(100),
	public_sampling_method		character varying(50),
	public_sampling_context		character varying(40),

	entity_type_id				int

) As $$

Declare
    entity_type_id int;

Begin

    entity_type_id := clearing_house.fn_get_entity_type_for('tbl_sample_groups');

	Return Query

		With sample_group (submission_id, source_id, local_db_id, public_db_id, merged_db_id, sample_group_name, sampling_method, sampling_context) As (
            Select sg.submission_id                 As submission_id,
                   sg.source_id                     As source_id,
                   sg.local_db_id                   As local_db_id,
                   sg.public_db_id                  As public_db_id,
                   sg.merged_db_id                  As merged_db_id,
                   sg.sample_group_name             As sample_group_name,
                   m.method_name                    As sampling_method,
                   c.sampling_context				As sampling_context
            From clearing_house.view_sample_groups sg
            Join clearing_house.view_methods m
              On m.merged_db_id = sg.method_id
             And m.submission_id in (0, sg.submission_id)
            Join clearing_house.view_sample_group_sampling_contexts c
              On c.merged_db_id = sg.sampling_context_id
             And c.submission_id in (0, sg.submission_id)
		)
			Select

				LDB.local_db_id						As local_db_id,

				LDB.sample_group_name				As sample_group_name,
				LDB.sampling_method					As sampling_method,
				LDB.sampling_context				As sampling_context,

				LDB.public_db_id					As public_db_id,

				RDB.sample_group_name				As public_sample_group_name,
				RDB.sampling_method					As public_sampling_method,
				RDB.sampling_context				As public_sampling_context,

                entity_type_id

			From sample_group LDB
			Left Join sample_group RDB
			  On RDB.source_id = 2
			 And RDB.public_db_id = LDB.public_db_id
			Where LDB.source_id = 1
			  And LDB.submission_id = $1
			  And LDB.local_db_id = -$2;

End $$ Language plpgsql;

/*****************************************************************************************************************************
**	Function	fn_clearinghouse_review_sample_group_lithology_client_data
**	Who			Roger Mähler
**	When		2013-11-13
**	What		Returns sample group lithology review data used by client
**	Uses
**	Used By
**	Revisions
******************************************************************************************************************************/
-- Select * From clearing_house.tbl_sites
-- Drop Function clearing_house.fn_clearinghouse_review_sample_group_lithology_client_data(int, int)
-- Select * From clearing_house.fn_clearinghouse_review_sample_group_lithology_client_data(2,-40)
Create Or Replace Function clearing_house.fn_clearinghouse_review_sample_group_lithology_client_data(int, int)
Returns Table (

	local_db_id				int,
    depth_top				numeric(20,5),
    depth_bottom			numeric(20,5),
	description				text,
	lower_boundary			character varying(255),

	public_db_id			int,
    public_depth_top		numeric(20,5),
    public_depth_bottom		numeric(20,5),
	public_description		text,
	public_lower_boundary	character varying(255),

	entity_type_id			int

) As $$

Declare
    entity_type_id int;

Begin

    entity_type_id := clearing_house.fn_get_entity_type_for('tbl_lithology');

	Return Query

			Select

				LDB.local_db_id		                    As local_db_id,

				LDB.depth_top                      		As depth_top,
				LDB.depth_bottom						As depth_bottom,
				LDB.description                  		As description,
				LDB.lower_boundary                 		As lower_boundary,

				LDB.public_db_id                        As public_db_id,
				RDB.depth_top                      		As public_depth_top,
				RDB.depth_bottom						As public_depth_bottom,
				RDB.description                  		As public_description,
				RDB.lower_boundary                 		As public_lower_boundary,

				entity_type_id              			As entity_type_id

			From (
				Select sg.submission_id					As submission_id,
					   sg.source_id						As source_id,
					   sg.merged_db_id					As sample_group_id,
					   l.local_db_id					As local_db_id,
					   l.public_db_id					As public_db_id,
					   l.merged_db_id					As lithology_id,
					   l.depth_top						As depth_top,
					   l.depth_bottom					As depth_bottom,
					   l.description					As description,
					   l.lower_boundary					As lower_boundary
				From clearing_house.view_sample_groups sg
				Join clearing_house.view_lithology l
				  On l.sample_group_id = sg.merged_db_id
				 And l.submission_id in (0, sg.submission_id)
			) As LDB Left Join (
				Select sg.sample_group_id				As sample_group_id,
					   l.lithology_id					As lithology_id,
					   l.depth_top						As depth_top,
					   l.depth_bottom					As depth_bottom,
					   l.description					As description,
					   l.lower_boundary					As lower_boundary
				From public.tbl_sample_groups sg
				Join public.tbl_lithology l
				  On l.sample_group_id = sg.sample_group_id
			) As RDB
			  On RDB.lithology_id = LDB.public_db_id
			Where LDB.source_id = 1
			  And LDB.submission_id = $1
			  And LDB.sample_group_id = -$2;

End $$ Language plpgsql;


/*****************************************************************************************************************************
**	Function	fn_clearinghouse_review_sample_group_references_client_data
**	Who			Roger Mähler
**	When		2013-11-13
**	What		Returns sample gourp reference review data used by client
**	Uses
**	Used By
**	Revisions
******************************************************************************************************************************/
-- Drop Function clearing_house.fn_clearinghouse_review_sample_group_references_client_data(int, int)
-- Select * From clearing_house.fn_clearinghouse_review_sample_group_references_client_data(2, -40)
Create Or Replace Function clearing_house.fn_clearinghouse_review_sample_group_references_client_data(int, int)
Returns Table (

	local_db_id int,
    reference text,

	public_db_id int,
    public_reference text,

    date_updated text,				-- display only if update

	entity_type_id int

) As $$
Declare
    entity_type_id int;
Begin

    entity_type_id := clearing_house.fn_get_entity_type_for('tbl_sample_group_references');

	Return Query

		Select
			LDB.sample_group_reference_id               As local_db_id,
			LDB.reference                               As reference,
			LDB.public_db_id                            As public_db_id,
			RDB.reference                               As public_reference,
			to_char(LDB.date_updated,'YYYY-MM-DD')		As date_updated,
			entity_type_id                      		As entity_type_id
		From (
			Select	sg.source_id						As source_id,
					sg.submission_id					As submission_id,
					sg.local_db_id						As sample_group_id,
					sr.local_db_id						As sample_group_reference_id,
					b.local_db_id						As local_db_id,
					b.public_db_id						As public_db_id,
					b.merged_db_id						As merged_db_id,
					b.authors || ' (' || b.year || ')'	As reference,
					sr.date_updated						As date_updated
			From clearing_house.view_sample_groups sg
			Join clearing_house.view_sample_group_references sr
			  On sr.sample_group_id = sg.merged_db_id
			 And sr.submission_id In (0, sg.submission_id)
			Join clearing_house.view_biblio b
			  On b.merged_db_id = sr.biblio_id
			 And b.submission_id In (0, sg.submission_id)
		) As LDB Left Join (
			Select	b.biblio_id							As biblio_id,
					b.authors || ' (' || b.year || ')'	As reference
			From public.tbl_biblio b
		) As RDB
		  On RDB.biblio_id = LDB.public_db_id
		Where LDB.source_id = 1
		  And LDB.submission_id = $1
		  And LDB.sample_group_id = -$2;

End $$ Language plpgsql;

/*****************************************************************************************************************************
**	Function	fn_clearinghouse_review_sample_group_notes_client_data
**	Who			Roger Mähler
**	When		2013-11-13
**	What		Returns sample group note review data used by client
**	Uses
**	Used By
**	Revisions
******************************************************************************************************************************/
-- Drop Function clearing_house.fn_clearinghouse_review_sample_group_notes_client_data(int, int)
-- Select * From clearing_house.fn_clearinghouse_review_sample_group_notes_client_data(2, -40)
Create Or Replace Function clearing_house.fn_clearinghouse_review_sample_group_notes_client_data(int, int)
Returns Table (

	local_db_id			int,
    note				character varying(255),

	public_db_id		int,
    public_note			character varying(255),

    date_updated		text,
	entity_type_id		int

) As $$
Declare
    entity_type_id int;
Begin

    entity_type_id := clearing_house.fn_get_entity_type_for('tbl_sample_group_notes');

	Return Query

		Select
			LDB.local_db_id					            As local_db_id,
			LDB.note                              		As note,
			LDB.public_db_id                            As public_db_id,
			RDB.note                               		As public_note,
			to_char(LDB.date_updated,'YYYY-MM-DD')		As date_updated,
			entity_type_id                  			As entity_type_id
		From (
			Select	sg.source_id						As source_id,
					sg.submission_id					As submission_id,
					sg.local_db_id						As sample_group_id,
					n.local_db_id						As local_db_id,
					n.public_db_id						As public_db_id,
					n.merged_db_id						As merged_db_id,
					n.note								As note,
					n.date_updated						As date_updated
			From clearing_house.view_sample_groups sg
			Join clearing_house.view_sample_group_notes n
			  On n.sample_group_id = sg.merged_db_id
			 And n.submission_id in (0, sg.submission_id)
		) As LDB Left Join (
			Select	n.sample_group_note_id				As sample_group_note_id,
					n.note								As note
			From public.tbl_sample_group_notes n
		) As RDB
		  On RDB.sample_group_note_id = LDB.public_db_id
		Where LDB.source_id = 1
		  And LDB.submission_id = $1
		  And LDB.sample_group_id = -$2;

End $$ Language plpgsql;

/*****************************************************************************************************************************
**	Function	fn_clearinghouse_review_sample_group_dimensions_client_data
**	Who			Roger Mähler
**	When		2013-11-13
**	What		Returns sample group dimension review data used by client
**	Uses
**	Used By
**	Revisions
******************************************************************************************************************************/
-- Drop Function clearing_house.fn_clearinghouse_review_sample_group_dimensions_client_data(int, int)
-- Select * From clearing_house.fn_clearinghouse_review_sample_group_dimensions_client_data(2, -40)
Create Or Replace Function clearing_house.fn_clearinghouse_review_sample_group_dimensions_client_data(int, int)
Returns Table (

	local_db_id						int,
    dimension_value					numeric(20,5),
    dimension_name					character varying(50),

	public_db_id					int,
    public_dimension_value			numeric(20,5),
    public_dimension_name			character varying(50),

    date_updated					text,
	entity_type_id					int

) As $$
Declare
    entity_type_id int;
Begin

    entity_type_id := clearing_house.fn_get_entity_type_for('tbl_sample_group_dimensions');

	Return Query

		Select
			LDB.local_db_id				               					As local_db_id,
			LDB.dimension_value                         				As dimension_value,
			LDB.dimension_name                         					As dimension_name,
			LDB.public_db_id				            				As public_db_id,
			RDB.dimension_value                         				As public_dimension_value,
			RDB.dimension_name                         					As public_dimension_name,
			to_char(LDB.date_updated,'YYYY-MM-DD')						As date_updated,
			entity_type_id												As entity_type_id
		From (
			Select	sg.source_id										As source_id,
					sg.submission_id									As submission_id,
					sg.local_db_id										As sample_group_id,
					d.local_db_id 										As local_db_id,
					d.public_db_id 										As public_db_id,
					d.merged_db_id 										As merged_db_id,
					d.dimension_value									As dimension_value,
					Coalesce(t.dimension_abbrev, t.dimension_name, '')	As dimension_name,
					d.date_updated										As date_updated
			From clearing_house.view_sample_groups sg
			Join clearing_house.view_sample_group_dimensions d
			  On d.sample_group_id = sg.merged_db_id
			 And d.submission_id in (0, sg.submission_id)
			Join clearing_house.view_dimensions t
			  On t.merged_db_id = d.dimension_id
			 And d.submission_id in (0, sg.submission_id)
		) As LDB Left Join (
			Select	d.sample_group_dimension_id 						As sample_group_dimension_id,
					d.dimension_value									As dimension_value,
					Coalesce(t.dimension_abbrev, t.dimension_name, '')	As dimension_name
			From public.tbl_sample_group_dimensions d
			Join public.tbl_dimensions t
			  On t.dimension_id = d.dimension_id
		  ) As RDB
		  On RDB.sample_group_dimension_id = LDB.public_db_id
		Where LDB.source_id = 1
		  And LDB.submission_id = $1
		  And LDB.sample_group_id = -$2;

End $$ Language plpgsql;


/*****************************************************************************************************************************
**	Function	fn_clearinghouse_review_sample_group_descriptions_client_data
**	Who			Roger Mähler
**	When		2013-11-13
**	What		Returns sample group descriptions review data used by client
**	Uses
**	Used By
**	Revisions
******************************************************************************************************************************/
-- Drop Function clearing_house.fn_clearinghouse_review_sample_group_descriptions_client_data(int, int)
-- Select * From clearing_house.fn_clearinghouse_review_sample_group_descriptions_client_data(2, -40)
Create Or Replace Function clearing_house.fn_clearinghouse_review_sample_group_descriptions_client_data(int, int)
Returns Table (

	local_db_id					int,
    group_description			character varying(255),
    type_name					character varying(255),
    type_description			character varying(255),

	public_db_id 				int,
    public_group_description	character varying(255),
    public_type_name			character varying(255),
    public_type_description		character varying(255),

	entity_type_id				int

) As $$
Declare
    entity_type_id int;
Begin

    entity_type_id := clearing_house.fn_get_entity_type_for('tbl_sample_group_descriptions');

	Return Query

		Select
			LDB.local_db_id				               					As local_db_id,
			LDB.group_description                       				As group_description,
			LDB.type_name                         						As type_name,
			LDB.type_description                       					As type_description,
			LDB.public_db_id				            				As public_db_id,
			RDB.group_description                      					As public_group_description,
			RDB.type_name                         						As public_type_name,
			RDB.type_description                       					As public_type_description,
			entity_type_id												As entity_type_id
		From (
			Select	sg.source_id										As source_id,
					sg.submission_id									As submission_id,
					sg.local_db_id										As sample_group_id,
					d.local_db_id										As local_db_id,
					d.public_db_id										As public_db_id,
					d.merged_db_id										As merged_db_id,
					d.group_description									As group_description,
					t.type_name											As type_name,
					t.type_description									As type_description
			From clearing_house.view_sample_groups sg
			Join clearing_house.view_sample_group_descriptions d
			  On sg.merged_db_id = d.sample_group_id
			 And d.submission_id in (0, sg.submission_id)
			Join clearing_house.view_sample_group_description_types t
			  On t.merged_db_id = d.sample_group_description_type_id
			 And t.submission_id in (0, sg.submission_id)
		) As LDB Left Join (
			Select	d.sample_group_description_id						As sample_group_description_id,
					d.group_description									As group_description,
					t.type_name											As type_name,
					t.type_description									As type_description
			From public.tbl_sample_groups sg
			Join public.tbl_sample_group_descriptions d
			  On d.sample_group_id = sg.sample_group_id
			Join public.tbl_sample_group_description_types t
			  On t.sample_group_description_type_id = d.sample_group_description_type_id
		  ) As RDB
		  On RDB.sample_group_description_id = LDB.public_db_id
		Where LDB.source_id = 1
		  And LDB.submission_id = $1
		  And LDB.sample_group_id = -$2;

End $$ Language plpgsql;


/*****************************************************************************************************************************
**	Function	fn_clearinghouse_review_sample_group_positions_client_data
**	Who			Roger Mähler
**	When		2013-11-13
**	What		Returns sample group descriptions positions review data used by client
**	Uses
**	Used By
**	Revisions   20180702 Merged sample_group_position & dimension_name
******************************************************************************************************************************/
-- Drop Function clearing_house.fn_clearinghouse_review_sample_group_positions_client_data(int, int)
-- Select * From clearing_house.fn_clearinghouse_review_sample_group_positions_client_data(2, -40)
Create Or Replace Function clearing_house.fn_clearinghouse_review_sample_group_positions_client_data(int, int)
Returns Table (

	local_db_id						int,
    sample_group_position			text,
    position_accuracy				character varying(128),
    method_name						character varying(50),

	public_db_id 					int,
    public_sample_group_position	text,
    public_position_accuracy		character varying(128),
    public_method_name				character varying(50),

	entity_type_id					int

) As $$
Declare
    entity_type_id int;
Begin

    entity_type_id := clearing_house.fn_get_entity_type_for('tbl_sample_group_coordinates');

	Return Query

		Select
			LDB.local_db_id				               	As local_db_id,
			format('%s %s', LDB.dimension_name,
                LDB.sample_group_position)              As sample_group_position,
			LDB.position_accuracy                       As position_accuracy,
			LDB.method_name                       		As method_name,
			LDB.public_db_id				            As public_db_id,
			format('%s %s', RDB.dimension_name,
                RDB.sample_group_position)              As public_sample_group_position,
			RDB.position_accuracy                       As public_position_accuracy,
			RDB.method_name                       		As public_method_name,
			entity_type_id								As entity_type_id
		From (
			Select	sg.source_id						As source_id,
					sg.submission_id					As submission_id,
					sg.local_db_id						As sample_group_id,
					d.local_db_id						As local_db_id,
					d.public_db_id						As public_db_id,
					d.merged_db_id						As merged_db_id,
					c.sample_group_position				As sample_group_position,
					c.position_accuracy					As position_accuracy,
					m.method_name						As method_name,
					d.dimension_name					As dimension_name
			From clearing_house.view_sample_groups sg
			Join clearing_house.view_sample_group_coordinates c
			  On c.sample_group_id = sg.merged_db_id
			 And c.submission_id In (0, sg.submission_id)
			Join clearing_house.view_coordinate_method_dimensions md
			  On md.merged_db_id = c.coordinate_method_dimension_id
			 And md.submission_id In (0, sg.submission_id)
			Join clearing_house.view_methods m
			  On m.merged_db_id = md.method_id
			 And m.submission_id In (0, sg.submission_id)
			Join clearing_house.view_dimensions d
			  On d.merged_db_id = md.dimension_id
			 And d.submission_id In (0, sg.submission_id)
			Where 1 = 1
		) As LDB Left Join (
			Select	c.sample_group_position_id			As sample_group_position_id,
					c.sample_group_position				As sample_group_position,
					c.position_accuracy					As position_accuracy,
					m.method_name						As method_name,
					d.dimension_name					As dimension_name
			From public.tbl_sample_group_coordinates c
			Join public.tbl_coordinate_method_dimensions md
			  On md.coordinate_method_dimension_id = c.coordinate_method_dimension_id
			Join public.tbl_methods m
			  On m.method_id = md.method_id
			Join public.tbl_dimensions d
			  On d.dimension_id = md.dimension_id
		) As RDB
		  On RDB.sample_group_position_id = LDB.public_db_id
		Where LDB.source_id = 1
		  And LDB.submission_id = $1
		  And LDB.sample_group_id = -$2;

End $$ Language plpgsql;
/*****************************************************************************************************************************
**	Function	fn_clearinghouse_review_site
**	Who			Roger Mähler
**	When		2013-11-07
**	What		Returns site data used by client
**	Uses
**	Used By
**	Revisions
******************************************************************************************************************************/
-- Select * From clearing_house.tbl_sites
--Drop Function clearing_house.fn_clearinghouse_review_site(int, int)
-- Select * From clearing_house.fn_clearinghouse_review_site(2, 27)
Create Or Replace Function clearing_house.fn_clearinghouse_review_site(int, int)
Returns Table (

	local_db_id int,
    latitude_dd numeric(18,10),
    longitude_dd numeric(18,10),
    altitude numeric(18,10),
	national_site_identifier character varying(255),
	site_name character varying(50),
	site_description text,
	preservation_status_or_threat character varying(255),
    site_location_accuracy character varying,

	public_db_id int,
	public_latitude_dd numeric(18,10),
	public_longitude_dd numeric(18,10),
	public_altitude  numeric(18,10),
	public_national_site_identifier character varying(255),
	public_site_name character varying(50),
	public_site_description text,
	public_preservation_status_or_threat character varying(255),
    public_site_location_accuracy character varying,

	entity_type_id int


) As $$

Declare
    site_entity_type_id int;

Begin

    site_entity_type_id := clearing_house.fn_get_entity_type_for('tbl_sites');

	Return Query
		With site_data (submission_id, source_id, site_id, local_db_id, public_db_id, latitude_dd, longitude_dd, altitude, national_site_identifier, site_name, site_description, site_location_accuracy, preservation_status_or_threat) As (
			Select  s.submission_id,
					s.source_id,
					s.site_id,
					s.local_db_id,
					s.public_db_id,
					s.latitude_dd,
					s.longitude_dd,
					s.altitude,
					s.national_site_identifier,
					s.site_name,
					s.site_description,
                    s.site_location_accuracy,
					t.preservation_status_or_threat
			From clearing_house.view_sites s
			Left Join clearing_house.view_site_preservation_status t
			  On t.merged_db_id = s.site_preservation_status_id
		)
			Select

				LDB.local_db_id						As local_db_id,

				LDB.latitude_dd						As latitude_dd,
				LDB.longitude_dd					As longitude_dd,
				LDB.altitude						As altitude,
				LDB.national_site_identifier		As national_site_identifier,
				LDB.site_name						As site_name,
				LDB.site_description				As site_description,
				LDB.preservation_status_or_threat	As preservation_status_or_threat,
				LDB.site_location_accuracy	        As site_location_accuracy,

				LDB.public_db_id					As public_db_id,
				RDB.latitude_dd						As public_latitude_dd,
				RDB.longitude_dd					As public_longitude_dd,
				RDB.altitude						As public_altitude,
				RDB.national_site_identifier		As public_national_site_identifier,
				RDB.site_name						As public_site_name,
				RDB.site_description				As public_site_description,
				RDB.preservation_status_or_threat	As public_preservation_status_or_threat,
				RDB.site_location_accuracy	        As public_site_location_accuracy,

                site_entity_type_id


			From site_data LDB
			Left Join site_data RDB
			  On RDB.source_id = 2
			 And RDB.site_id = LDB.public_db_id
			Where LDB.source_id = 1
			  And LDB.submission_id = $1
			  And LDB.site_id = $2;

End $$ Language plpgsql;

/*****************************************************************************************************************************
**	Function	fn_clearinghouse_review_site_locations
**	Who			Roger Mähler
**	When		2013-11-07
**	What		Returns site locations used by client
**	Uses
**	Used By
**	Revisions
******************************************************************************************************************************/
-- Select * From clearing_house.tbl_sites
-- Drop Function clearing_house.fn_clearinghouse_review_site_locations(int, int)
-- Select * From clearing_house.fn_clearinghouse_review_site_locations(2, 27)
Create Or Replace Function clearing_house.fn_clearinghouse_review_site_locations(int, int)
Returns Table (

	local_db_id int,
    location_name character varying(255),
    location_type character varying(40),
	default_lat_dd numeric(18,10),
	default_long_dd numeric(18,10),

	public_db_id int,
    public_location_name character varying(255),
    public_location_type character varying(40),
	public_default_lat_dd numeric(18,10),
	public_default_long_dd numeric(18,10),

    date_updated text,

	entity_type_id int

) As $$

Declare
    entity_type_id int;

Begin

    entity_type_id := clearing_house.fn_get_entity_type_for('tbl_site_locations');

	Return Query

			Select

				LDB.site_location_id                    As local_db_id,

				LDB.location_name                       As location_name,
				LDB.location_type                       As location_type,
				LDB.default_lat_dd                  	As default_lat_dd,
				LDB.default_long_dd                 	As default_long_dd,

				LDB.public_db_id                        As public_db_id,

				RDB.location_name                   	As public_location_name,
				RDB.location_type               		As public_location_type,
				RDB.default_lat_dd              		As public_default_lat_dd,
				RDB.default_long_dd                     As public_default_long_dd,

				to_char(LDB.date_updated,'YYYY-MM-DD')	As date_updated,

				entity_type_id			As entity_type_id

			From (
				Select s.submission_id, sl.site_location_id, s.source_id, s.site_id, l.location_id, l.local_db_id, l.public_db_id, l.location_name, l.date_updated, t.location_type, l.default_lat_dd, l.default_long_dd
				From clearing_house.view_sites s
				Left Join clearing_house.view_site_locations sl
				  On sl.site_id = s.merged_db_id
				 And sl.submission_id In (0, $1)
				Left Join clearing_house.view_locations l
				  On l.merged_db_id = sl.location_id
				 And sl.submission_id In (0, $1)
				Join clearing_house.view_location_types t
				  On t.merged_db_id = l.location_type_id
				 And t.submission_id In (0, $1)
				Where 1 = 1
			) As LDB Left Join (
				Select l.location_id, l.location_name, l.date_updated, t.location_type, l.default_lat_dd, l.default_long_dd
				From public.tbl_locations l
				Join public.tbl_location_types t
				  On t.location_type_id = l.location_type_id
				Where 1 = 1
			) As RDB
			  On RDB.location_id = LDB.public_db_id
			Where LDB.source_id = 1
			  And LDB.submission_id = $1
			  And LDB.site_id = $2;

End $$ Language plpgsql;


/*****************************************************************************************************************************
**	Function	fn_clearinghouse_review_site_references
**	Who			Roger Mähler
**	When		2013-11-07
**	What		Returns site locations used by client
**	Uses
**	Used By
**	Revisions
******************************************************************************************************************************/
-- Select * From clearing_house.tbl_sites
-- Drop Function clearing_house.fn_clearinghouse_review_site_references(int, int)
-- Select * From clearing_house.fn_clearinghouse_review_site_references(2, 27)
Create Or Replace Function clearing_house.fn_clearinghouse_review_site_references(int, int)
Returns Table (

	local_db_id int,
    reference text,

	public_db_id int,
    public_reference text,

    date_updated text,				-- display only if update

	entity_type_id int

) As $$

Declare
    entity_type_id int;

Begin

    entity_type_id := clearing_house.fn_get_entity_type_for('tbl_site_references');

	Return Query

		Select
			LDB.site_reference_id                       As local_db_id,
			LDB.full_reference                          As reference,
			LDB.public_db_id                            As public_db_id,
			RDB.full_reference                          As public_reference,
			to_char(LDB.date_updated,'YYYY-MM-DD')		As date_updated,
			entity_type_id              				As entity_type_id
		From (
			Select  s.source_id,
                    s.submission_id,
                    sr.site_reference_id,
                    s.site_id,
                    b.biblio_id as local_db_id,
                    b.public_db_id,
                    b.full_reference,
                    b.date_updated
			From clearing_house.view_sites s
			Join clearing_house.view_site_references sr
			  On sr.site_id = s.merged_db_id
			 And sr.submission_id In (0, $1)
			Join clearing_house.view_biblio b
			  On b.merged_db_id = sr.biblio_id
			 And b.submission_id In (0, $1)
		) As LDB Left Join (
			Select  b.biblio_id,
                    b.full_reference
			From public.tbl_biblio b
		) As RDB
		  On RDB.biblio_id = LDB.public_db_id
		Where LDB.source_id = 1
		  And LDB.submission_id = $1
		  And LDB.site_id = $2;

End $$ Language plpgsql;

/*****************************************************************************************************************************
**	Function	fn_clearinghouse_review_site_natgridrefs
**	Who			Roger Mähler
**	When		2013-11-07
**	What		Returns site natgridrefs used by client
**	Uses
**	Used By
**	Revisions
******************************************************************************************************************************/
-- Select * From clearing_house.tbl_sites
-- Drop Function clearing_house.fn_clearinghouse_review_site_natgridrefs(int, int)
-- Select * From clearing_house.fn_clearinghouse_review_site_natgridrefs(2, 27)
Create Or Replace Function clearing_house.fn_clearinghouse_review_site_natgridrefs(int, int)
Returns Table (

	local_db_id int,
    method_name character varying(50),
    natgridref character varying,

	public_db_id int,
    public_method_name character varying(50),
    public_natgridref character varying,				-- display only if update

	entity_type_id int

) As $$

Declare
    entity_type_id int;

Begin

    entity_type_id := clearing_house.fn_get_entity_type_for('tbl_site_natgridrefs');

	Return Query

		Select
			LDB.site_natgridref_id			As local_db_id,
			LDB.method_name					As method_name,
			LDB.natgridref					As natgridref,
			LDB.public_db_id				As public_db_id,
			RDB.method_name					As public_method_name,
			RDB.natgridref					As public_natgridref,
			entity_type_id          		As entity_type_id
		From (
			Select s.source_id, sg.site_natgridref_id, s.submission_id, s.site_id, sg.site_natgridref_id as local_db_id, sg.public_db_id, m.method_name, sg.natgridref
			From clearing_house.view_sites s
			Join clearing_house.view_site_natgridrefs sg
			  On sg.site_id = s.merged_db_id
			 And sg.submission_id In (0, $1)
			Join clearing_house.view_methods m
			  On m.merged_db_id = sg.method_id
			 And m.submission_id In (0, $1)
			Where 1 = 1
		) As LDB Left Join (
			Select sg.site_natgridref_id, m.method_name, sg.natgridref
			From public.tbl_site_natgridrefs sg
			Join public.tbl_methods m
			  On m.method_id = sg.method_id
			Where 1 = 1
		) As RDB
		  On RDB.site_natgridref_id = LDB.public_db_id
		Where LDB.source_id = 1
		  And LDB.submission_id = $1
		  And LDB.site_id = $2;

End $$ Language plpgsql;


create or replace function clearing_house.fn_clearinghouse_review_site_projects(p_submission_id integer, p_site_id integer)
  returns table(
    local_db_id integer,
    site_id integer,
    site_name character varying,
    project_name character varying,
    project_abbrev character varying,
    project_type character varying,
    description character varying,
    public_db_id integer,
    public_site_id integer,
    public_site_name character varying,
    public_project_name character varying,
    public_project_abbrev character varying,
    public_project_type character varying,
    public_description character varying,
    date_updated text,
    entity_type_id integer
) as
$body$
declare
    entity_type_id int;
begin

    entity_type_id := clearing_house.fn_get_entity_type_for('tbl_projects');

    return query

        select distinct
            ldb.local_db_id                                      as local_db_id,

            ldb.site_id                                          as site_id,
            ldb.site_name                                        as site_name,
            ldb.project_name                                     as project_name,
            ldb.project_abbrev                                   as project_abbrev,
            ldb.project_type::character varying                  as project_type,
            ldb.description::character varying                   as description,

            ldb.public_db_id                                     as public_db_id,

            rdb.site_id                                          as public_site_id,
            rdb.site_name                                        as public_site_name,
            rdb.project_name                                     as public_project_name,
            rdb.project_abbrev                                   as public_project_abbrev,
            ldb.project_type::character varying                  as public_project_type,
            rdb.description::character varying                   as public_description,

            to_char(ldb.date_updated,'yyyy-mm-dd')               as date_updated,
            entity_type_id                                       as entity_type_id

        from (
            select  p.source_id                                  as source_id,
                    p.submission_id                              as submission_id,
                    s.local_db_id                                as site_id,
                    p.local_db_id                                as local_db_id,
                    p.public_db_id                               as public_db_id,

                    s.site_name                                  as site_name,
                    p.project_name                               as project_name,
                    p.project_abbrev_name                        as project_abbrev,
                    p.description                                as description,
                    prs.stage_name ||', '|| pt.project_type_name as project_type,
                    p.date_updated                               as date_updated

            from clearing_house.view_projects p
            join clearing_house.view_project_types pt
              on pt.merged_db_id = p.project_type_id
             and pt.submission_id in (0, p.submission_id)
            join clearing_house.view_project_stages prs
              on prs.merged_db_id = p.project_stage_id
             and prs.submission_id in (0, p.submission_id)
            join clearing_house.view_datasets d
              on p.merged_db_id = d.project_id
             and d.submission_id in (0, p.submission_id)
            join clearing_house.view_analysis_entities ae
              on d.merged_db_id = ae.dataset_id
             and ae.submission_id in (0, p.submission_id)
            join clearing_house.view_physical_samples ps
              on ps.merged_db_id = ae.physical_sample_id
             and ps.submission_id in (0, p.submission_id)
            join clearing_house.view_sample_groups sg
              on sg.merged_db_id = ps.sample_group_id
             and sg.submission_id in (0, p.submission_id)
            join clearing_house.view_sites s
              on s.merged_db_id = sg.site_id
             and s.submission_id in (0, p.submission_id)

        ) as ldb left join (

            select
                    s.site_id                                     as site_id,
                    s.site_name                                   as site_name,
                    p.project_id                                  as project_id,
                    p.project_name                                as project_name,
                    p.project_abbrev_name                         as project_abbrev,
                    p.description                                 as description,
                    prs.stage_name ||', '|| pt.project_type_name  as project_type,
                    p.date_updated                                as date_updated


            from public.tbl_projects p
            join public.tbl_project_types pt
              on pt.project_type_id = p.project_type_id
            join public.tbl_project_stages prs
              on prs.project_stage_id = p.project_stage_id
            join public.tbl_datasets d
              on p.project_id = d.project_id
            join public.tbl_analysis_entities ae
              on d.dataset_id = ae.dataset_id
            join public.tbl_physical_samples ps
              on ps.physical_sample_id = ae.physical_sample_id
            join public.tbl_sample_groups sg
              on sg.sample_group_id = ps.sample_group_id
            join public.tbl_sites s
              on s.site_id = sg.site_id

          ) as rdb
          on rdb.project_id = ldb.public_db_id
        where ldb.source_id = 1
          and ldb.submission_id = p_submission_id
          and ldb.site_id = -p_site_id
        ;

end $body$
  language plpgsql volatile
  cost 100
  rows 1000;

alter function clearing_house.fn_clearinghouse_review_site_projects(integer, integer)
  owner to clearinghouse_worker;
﻿/*****************************************************************************************************************************
**	Function	fn_clearinghouse_report_locations
**	Who			Roger Mähler
**	When		2013-10-14
**	What		Displays all locations found in the submissed data
**	Uses
**	Used By
**	Revisions
******************************************************************************************************************************/
-- Select * From clearing_house.fn_clearinghouse_report_locations(2)
Create Or Replace Function clearing_house.fn_clearinghouse_report_locations(int)
Returns Table (

	local_db_id int,
	entity_type_id int,

	location_id int,
	location_name character varying(255),
	default_lat_dd numeric(18,10),
	default_long_dd numeric(18,10),
	date_updated text,
	location_type_id int,
	location_type character varying(40),
	description text,

	public_location_id int,
	public_location_name character varying(255),
	public_default_lat_dd numeric(18,10),
	public_default_long_dd numeric(18,10),
	public_location_type_id int,
	public_location_type character varying(40),
	public_description text

) As $$

Declare
    entity_type_id int;
Begin

	entity_type_id := clearing_house.fn_get_entity_type_for('tbl_locations');

	Return Query
		Select	l.local_db_id						                            as local_db_id,
				entity_type_id						                            as entity_type_id,
				l.local_db_id						                            as location_id,
				l.location_name						                            as location_name,
				l.default_lat_dd                                                as default_lat_dd,
				l.default_long_dd                                               as default_long_dd,
				to_char(l.date_updated,'YYYY-MM-DD')                            as date_updated,
				l.location_type_id                                              as location_type_id,
				Coalesce(t.location_type, p.location_type)						as location_type,
				t.description						                            as description,

				p.location_id						                            as public_location_id,
				p.location_name						                            as public_location_name,
				p.default_lat_dd					                            as public_default_lat_dd,
				p.default_long_dd					                            as public_default_long_dd,
				p.location_type_id					                            as public_location_type_id,
				p.location_type						                            as public_location_type,
				p.description						                            as public_description

		From clearing_house.view_locations l
		Join clearing_house.view_location_types t
		  On t.merged_db_id = l.location_type_id
		 And t.submission_id In (0, l.submission_id)
		Full Outer Join(
			Select l.location_id, l.location_name, l.default_lat_dd, l.default_long_dd, t.location_type_id, t.location_type, t.description
			From public.tbl_locations l
			Join public.tbl_location_types t
			  On t.location_type_id = l.location_type_id
		) as p
		  On p.location_id = l.public_db_id
		Where l.submission_id = $1;

End $$ Language plpgsql;

/*****************************************************************************************************************************
**	Function	fn_clearinghouse_report_bibliographic_entries
**	Who			Roger Mähler
**	When		2013-10-14
**	What		Displays all bibliographic entries found in the submissed data
**	Uses
**	Used By
**	Revisions
******************************************************************************************************************************/
-- Drop Function If Exists clearing_house.fn_clearinghouse_report_bibliographic_entries(int);
-- Select * From clearing_house.fn_clearinghouse_report_bibliographic_entries(32)
Create Or Replace Function clearing_house.fn_clearinghouse_report_bibliographic_entries(int)
Returns Table (

	local_db_id int,
    authors varchar,
    title varchar,
    full_reference text,
    url varchar,
    doi varchar,

	public_db_id int,

    public_authors varchar,
    public_title varchar,
    public_full_reference text,
    public_url varchar,
    public_doi varchar,

    date_updated text,				-- display only if update

	entity_type_id int

) As $$

Declare
    entity_type_id int;

Begin

    entity_type_id := clearing_house.fn_get_entity_type_for('tbl_biblio');

	Return Query

		Select
			LDB.local_db_id                            	As local_db_id,
			LDB.authors                                 As authors,
			LDB.title                                   As title,
			LDB.full_reference                          As full_reference,
			LDB.url                                     As url,
			LDB.doi                                     As doi,

			LDB.public_db_id                            As public_db_id,

			RDB.authors                                 As public_authors,
			RDB.title                                   As public_title,
			RDB.full_reference                          As public_full_reference,
			RDB.url                                     As public_url,
			RDB.doi                                     As doi,

			to_char(LDB.date_updated,'YYYY-MM-DD')		As date_updated,
			entity_type_id              				As entity_type_id
		From (

			Select	b.submission_id																			As submission_id,
					b.source_id																				As source_id,
					b.biblio_id																				As local_db_id,
					b.public_db_id																			As public_db_id,
					b.authors                    													        As authors,
					b.full_reference                    													As full_reference,
					b.title															                        As title,
					b.url															                        As url,
					b.doi															                        As doi,
					b.date_updated																			As date_updated

			From clearing_house.view_biblio b

		) As LDB Left Join (

			Select	b.biblio_id																				As biblio_id,
					b.authors                    													        As authors,
					b.full_reference                														As full_reference,
					b.title   														                        As title,
					b.url   														                        As url,
					b.doi   														                        As doi,
					b.date_updated																			As date_updated

			From public.tbl_biblio b

		) As RDB
		  On RDB.biblio_id = LDB.public_db_id

		Where LDB.source_id = 1
		  And LDB.submission_id = $1;

End $$ Language plpgsql;

/*****************************************************************************************************************************
**	Function	fn_clearinghouse_report_taxonomic_order
**	Who			Roger Mähler
**	When		2013-11-19
**	What		Displays taxonomic order found in the submissed data
**	Uses
**	Used By
**	Revisions
******************************************************************************************************************************/
-- Drop Function clearing_house.fn_clearinghouse_report_taxonomic_order(int)
-- Select * From clearing_house.fn_clearinghouse_report_taxonomic_order(2)
Create Or Replace Function clearing_house.fn_clearinghouse_report_taxonomic_order(int)
Returns Table (

	local_db_id int,

	species text,
	taxonomic_code numeric(18,10),
	system_name character varying,
	reference text,

	public_db_id int,

	public_species text,
	public_taxonomic_code numeric(18,10),
	public_system_name character varying,
	public_reference text,

    date_updated text,
	entity_type_id int

) As $$

Declare
    entity_type_id int;

Begin

    entity_type_id := clearing_house.fn_get_entity_type_for('tbl_taxonomic_order ');

	Return Query

		Select
			LDB.local_db_id                            	As local_db_id,

			LDB.species,
			LDB.taxonomic_code,
			LDB.system_name,
			LDB.reference,

  			LDB.public_db_id                            As public_db_id,

			RDB.public_species,
			RDB.public_taxonomic_code,
			RDB.public_system_name,
			RDB.public_reference,


			to_char(LDB.date_updated,'YYYY-MM-DD')		As date_updated,
			entity_type_id              				As entity_type_id

		From (

				select t.submission_id,
					   t.source_id,
					   t.taxon_id																As local_db_id,
					   t.public_db_id															As public_db_id,
					   g.genus_name || ' ' || t.species || ' ' || coalesce(a.author_name, '')	As species,
					   o.taxonomic_code,
					   s.system_name,
					   b.authors || '(' || b.year || ')' as reference,
					   t.date_updated

				from clearing_house.view_taxa_tree_master t
				join clearing_house.view_taxa_tree_genera g
				  on t.genus_id = g.merged_db_id
				 and g.submission_id in (0, t.submission_id)
				left join clearing_house.view_taxa_tree_authors a
				  on t.author_id = a.merged_db_id
				 and a.submission_id in (0, t.submission_id)
				Join clearing_house.view_taxonomic_order o
				  on o.taxon_id = t.merged_db_id
				 and o.submission_id in (0, t.submission_id)
				Join clearing_house.view_taxonomic_order_systems s
				  On o.taxonomic_order_system_id = s.merged_db_id
				 And s.submission_id in (0, o.submission_id)
				Join clearing_house.view_taxonomic_order_biblio bo
				  On bo.taxonomic_order_system_id = s.merged_db_id
				 And bo.submission_id in (0, o.submission_id)
				Join clearing_house.view_biblio b
				  On b.merged_db_id = bo.biblio_id
				 And b.submission_id in (0, o.submission_id)
				--Where o.submission_id = $1
				--Order by 4 /* species */

		) As LDB Left Join (

				select t.taxon_id As taxon_id,
					   g.genus_name || ' ' || t.species || ' ' || coalesce(a.author_name, '')	As public_species,
					   o.taxonomic_code															As public_taxonomic_code,
					   s.system_name															As public_system_name,
					   b.authors || '(' || b.year || ')'											as public_reference

				from public.tbl_taxa_tree_master t
				join public.tbl_taxa_tree_genera g
				  on t.genus_id = g.genus_id
				left join public.tbl_taxa_tree_authors a
				  on t.author_id = a.author_id
				Join public.tbl_taxonomic_order o
				  on o.taxon_id = t.taxon_id
				Join public.tbl_taxonomic_order_systems s
				  On o.taxonomic_order_system_id = s.taxonomic_order_system_id
				Join public.tbl_taxonomic_order_biblio bo
				  On bo.taxonomic_order_system_id = s.taxonomic_order_system_id
				Join public.tbl_biblio b
				  On b.biblio_id = bo.biblio_id
				--Where o.submission_id = $1
				--Order by 4 /* species */

		) As RDB
		  On RDB.taxon_id = LDB.public_db_id
		Where LDB.source_id = 1
		  And LDB.submission_id = $1
		Order By LDB.species;
End $$ Language plpgsql;
/*****************************************************************************************************************************
**	Function	fn_clearinghouse_report_taxa_rdb
**	Who			Erik Eriksson
**	When		2013-11-21
**	What		Displays RDB data for a taxa found in the (supplied) submission data
**	Uses
**	Used By
**	Revisions
******************************************************************************************************************************/
-- Drop Function clearing_house.fn_clearinghouse_report_taxa_rdb(int)
-- Select * From clearing_house.fn_clearinghouse_report_taxa_rdb(2)
Create Or Replace Function clearing_house.fn_clearinghouse_report_taxa_rdb(int)
Returns Table (

	local_db_id int,

	species text,
    location_name character varying,
	rdb_category character varying,
    rdb_definition character varying,
	rdb_system character varying,
	reference text,

	public_db_id int,

	public_species text,
	public_location_name character varying,
	public_rdb_category character varying,
    public_rdb_definition character varying,
	public_rdb_system character varying,
    public_reference text,

    date_updated text,
	entity_type_id int

) As $$

Declare
    entity_type_id int;

Begin

    entity_type_id := clearing_house.fn_get_entity_type_for('tbl_rdb ');

	Return Query

		Select
			LDB.local_db_id                            	As local_db_id,

			LDB.species,
			LDB.location_name,
			LDB.rdb_category,
			LDB.rdb_definition,
			LDB.rdb_system,
			LDB.reference,

  			LDB.public_db_id                            As public_db_id,

			RDB.public_species,
			RDB.public_location_name,
			RDB.public_rdb_category,
			RDB.public_rdb_definition,
			RDB.public_rdb_system,
			RDB.public_reference,


			to_char(LDB.date_updated,'YYYY-MM-DD')		As date_updated,
			entity_type_id              				As entity_type_id

		From (

				select t.submission_id,
					t.source_id,
					t.taxon_id As local_db_id,
					t.public_db_id As public_db_id,
					g.genus_name || ' ' || t.species || ' ' || coalesce(a.author_name, '')	As species,
					l.location_name,
					c.rdb_category,
					c.rdb_definition,
					s.rdb_system,
					b.authors || '(' || b.year || ')' as reference,
					t.date_updated

				from clearing_house.view_taxa_tree_master t
				join clearing_house.view_taxa_tree_genera g
				  on t.genus_id = g.merged_db_id
				 and g.submission_id in (0, t.submission_id)
				left join clearing_house.view_taxa_tree_authors a
				  on t.author_id = a.merged_db_id
				 and a.submission_id in (0, t.submission_id)
				join clearing_house.view_rdb r
				  on r.taxon_id = t.merged_db_id
				 and r.submission_id in (0, t.submission_id)
				join clearing_house.view_rdb_codes c
				  on c.merged_db_id = r.rdb_code_id
				 and c.submission_id in (0, t.submission_id)
				join clearing_house.view_rdb_systems s
				  on s.merged_db_id = c.rdb_system_id
				 and s.submission_id in (0, t.submission_id)
				Join clearing_house.view_biblio b
				  On b.merged_db_id = s.biblio_id
				 And b.submission_id in (0, t.submission_id)
				join clearing_house.view_locations l
				  on l.merged_db_id = r.location_id
				 and l.submission_id in (0, t.submission_id)


		) As LDB Left Join (

				select
					t.taxon_id As taxon_id,
					g.genus_name || ' ' || t.species || ' ' || coalesce(a.author_name, '')	As public_species,
					l.location_name as public_location_name,
					c.rdb_category as public_rdb_category,
					c.rdb_definition as public_rdb_definition,
					s.rdb_system as public_rdb_system,
					b.authors || '(' || b.year || ')' as public_reference,
					t.date_updated

				from clearing_house.tbl_taxa_tree_master t
				join clearing_house.tbl_taxa_tree_genera g
				  on t.genus_id = g.genus_id
				left join public.tbl_taxa_tree_authors a
				  on t.author_id = a.author_id
				join public.tbl_rdb r
				  on r.taxon_id = t.taxon_id
				join public.tbl_rdb_codes c
				  on c.rdb_code_id = r.rdb_code_id
				join public.tbl_rdb_systems s
				  on s.rdb_system_id = c.rdb_system_id
				Join public.tbl_biblio b
				  On b.biblio_id = s.biblio_id
				join public.tbl_locations l
				  on l.location_id = r.location_id

		) As RDB
		  On RDB.taxon_id = LDB.public_db_id
		Where LDB.source_id = 1
		  And LDB.submission_id = $1
		Order By LDB.species;
End $$ Language plpgsql;
/*****************************************************************************************************************************
**	Function	fn_clearinghouse_report_taxa_ecocodes
**	Who			Erik Eriksson
**	When		2013-11-21
**	What		Displays ecocode data for a taxa found in the (supplied) submission data
**	Uses
**	Used By
**	Revisions
******************************************************************************************************************************/
-- Drop Function clearing_house.fn_clearinghouse_report_taxa_ecocodes(int)
-- Select * From clearing_house.fn_clearinghouse_report_taxa_ecocodes(2)
Create Or Replace Function clearing_house.fn_clearinghouse_report_taxa_ecocodes(int)
Returns Table (

	local_db_id int,

	species text,
	abbreviation character varying,
	label character varying,
	definition text,
	notes text,
	group_label character varying,
	system_name character varying,
	reference text,

	public_db_id int,

	public_species text,
	public_abbreviation character varying,
	public_label character varying,
	public_definition text,
	public_notes text,
	public_group_label character varying,
	public_system_name character varying,
	public_reference text,

    date_updated text,
	entity_type_id int

) As $$

Declare
    entity_type_id int;

Begin

    entity_type_id := clearing_house.fn_get_entity_type_for('tbl_ecocodes ');

	Return Query

		Select
			LDB.local_db_id                            	As local_db_id,

			LDB.species,
			LDB.abbreviation,
			LDB.label,
			LDB.definition,
			LDB.notes,
			LDB.group_label,
			LDB.system_name,
			LDB.reference,

  			LDB.public_db_id                            As public_db_id,

			RDB.public_species,
			RDB.public_abbreviation,
			RDB.public_label,
			RDB.public_definition,
			RDB.public_notes,
			RDB.public_group_label,
			RDB.public_system_name,
			RDB.public_reference,

			to_char(LDB.date_updated,'YYYY-MM-DD')		As date_updated,
			entity_type_id              				As entity_type_id

		From (
				select t.submission_id,
					t.source_id,
					t.taxon_id As local_db_id,
					t.public_db_id As public_db_id,
					g.genus_name || ' ' || t.species || ' ' || coalesce(a.author_name, '')	As species,
					ed.abbreviation,
					ed.label,
					ed.definition,
					ed.notes,
					eg.label as group_label,
					es.name as system_name,
					b.authors || '(' || b.year || ')' as reference,
					t.date_updated

				from clearing_house.view_taxa_tree_master t
				join clearing_house.view_taxa_tree_genera g
				  on t.genus_id = g.merged_db_id
				 and g.submission_id in (0, t.submission_id)
				left join clearing_house.view_taxa_tree_authors a
				  on t.author_id = a.merged_db_id
				 and a.submission_id in (0, t.submission_id)
                                join clearing_house.view_ecocodes e
                                  on e.taxon_id = t.merged_db_id
                                 and e.submission_id in (0, t.submission_id)
                                join clearing_house.view_ecocode_definitions ed
                                  on ed.merged_db_id = e.ecocode_definition_id
                                 and ed.submission_id in (0, t.submission_id)
                                join clearing_house.view_ecocode_groups eg
                                  on eg.merged_db_id = ed.ecocode_group_id
                                 and eg.submission_id in (0, t.submission_id)
                                join clearing_house.view_ecocode_systems es
                                  on es.merged_db_id = eg.ecocode_system_id
                                 and es.submission_id in (0, t.submission_id)
				Join clearing_house.view_biblio b
				  On b.merged_db_id = es.biblio_id
				 And b.submission_id in (0, t.submission_id)

		) As LDB Left Join (

				select
					t.taxon_id As taxon_id,
					g.genus_name || ' ' || t.species || ' ' || coalesce(a.author_name, '')	As public_species,
					ed.abbreviation as public_abbreviation,
					ed.label as public_label,
					ed.definition as public_definition,
					ed.notes as public_notes,
					eg.label as public_group_label,
					es.name as public_system_name,
					b.authors || '(' || b.year || ')' as public_reference,
					t.date_updated

				from public.tbl_taxa_tree_master t
				join public.tbl_taxa_tree_genera g
				  on t.genus_id = g.genus_id
				left join public.tbl_taxa_tree_authors a
				  on t.author_id = a.author_id
				join public.tbl_ecocodes e
				  on e.taxon_id = t.taxon_id
				join public.tbl_ecocode_definitions ed
				  on ed.ecocode_definition_id = e.ecocode_definition_id
				join public.tbl_ecocode_groups eg
				  on eg.ecocode_group_id = ed.ecocode_group_id
				join public.tbl_ecocode_systems es
				  on es.ecocode_system_id = eg.ecocode_system_id
				Join public.tbl_biblio b
				  On b.biblio_id = es.biblio_id

		) As RDB
		  On RDB.taxon_id = LDB.public_db_id
		Where LDB.source_id = 1
		  And LDB.submission_id = $1
		Order By LDB.species;
End $$ Language plpgsql;
/*****************************************************************************************************************************
**	Function	fn_clearinghouse_report_taxa_tree_master
**	Who			Erik Eriksson
**	When		2013-11-21
**	What		Displays taxa data for uploaded species, together with associations and common names
**	Uses
**	Used By
**	Revisions
******************************************************************************************************************************/
-- Drop Function clearing_house.fn_clearinghouse_report_taxa_tree_master(int)
-- Select * From clearing_house.fn_clearinghouse_report_taxa_tree_master(2)
Create Or Replace Function clearing_house.fn_clearinghouse_report_taxa_tree_master(int)
Returns Table (

	local_db_id int,

	order_name character varying,
	family character varying,
	species text,
	association_type_name character varying,
	association_species text,
	common_name character varying,
	language_name character varying,

	public_db_id int,

	public_order_name character varying,
	public_family character varying,
	public_species text,
	public_association_type_name character varying,
	public_association_species text,
	public_common_name character varying,
	public_language_name character varying,

    date_updated text,
	entity_type_id int

) As $$

Declare
    entity_type_id int;

Begin

    entity_type_id := clearing_house.fn_get_entity_type_for('tbl_taxa_tree_master ');

	Return Query

		Select
			LDB.local_db_id                            	As local_db_id,

			LDB.order_name,
			LDB.family,
			LDB.species,
			LDB.association_type_name,
			LDB.association_species,
			LDB.common_name,
			LDB.language_name,

  			LDB.public_db_id                            As public_db_id,

			RDB.public_order_name,
			RDB.public_family,
			RDB.public_species,
			RDB.public_association_type_name,
			RDB.public_association_species,
			RDB.public_common_name,
			RDB.public_language_name,

			to_char(LDB.date_updated,'YYYY-MM-DD')		As date_updated,
			entity_type_id              				As entity_type_id

		From (

			select t.submission_id,
				t.source_id,
				t.taxon_id As local_db_id,
				t.public_db_id As public_db_id,
				o.order_name as order_name,
				f.family_name as family,
				g.genus_name || ' ' || t.species || ' ' || coalesce(a.author_name, '')	As species,
				sat.association_type_name,
				sa_genera.genus_name || ' ' || sa_species.species || ' ' || coalesce(sa_authors.author_name, '') as association_species,
				cn.common_name,
				l.language_name_english as language_name,
				t.date_updated
			from clearing_house.view_taxa_tree_master t
			join clearing_house.view_taxa_tree_genera g
			 on t.genus_id = g.merged_db_id
			 and g.submission_id in (0, t.submission_id)
			join clearing_house.view_taxa_tree_families f
			 on g.family_id = f.merged_db_id
			 and f.submission_id in (0, t.submission_id)
			join clearing_house.view_taxa_tree_orders o
			 on o.order_id = f.merged_db_id
			 and o.submission_id in (0, t.submission_id)
			left join clearing_house.view_taxa_tree_authors a
			 on t.author_id = a.merged_db_id
			 and a.submission_id in (0, t.submission_id)
			-- associations
			left join clearing_house.view_species_associations sa
			 on t.taxon_id = sa.merged_db_id
			 and sa.submission_id in (0, t.submission_id)
			left join clearing_house.view_species_association_types sat
			 on sat.association_type_id = sa.merged_db_id
			 and sat.submission_id in (0, t.submission_id)
			left join clearing_house.view_taxa_tree_master sa_species
			 on sa.associated_taxon_id = sa_species.merged_db_id
			 and sa_species.submission_id in (0, t.submission_id)
			left join clearing_house.view_taxa_tree_genera sa_genera
			 on sa_species.genus_id = sa_genera.merged_db_id
			 and sa_genera.submission_id in (0, t.submission_id)
			left join clearing_house.view_taxa_tree_authors sa_authors
			 on sa_species.author_id = sa_authors.merged_db_id
			 and sa_authors.submission_id in (0, t.submission_id)
			-- // end associations
			--common names
			left join clearing_house.view_taxa_common_names cn
			 on cn.merged_db_id = t.taxon_id
			 and cn.submission_id in (0, t.submission_id)
			left join clearing_house.view_languages l
			 on cn.language_id = l.merged_db_id
			 and l.submission_id in (0, t.submission_id)
            -- // end common names

		) As LDB Left Join (
			select
				t.taxon_id As taxon_id,
				o.order_name as public_order_name,
				f.family_name as public_family,
				g.genus_name || ' ' || t.species || ' ' || coalesce(a.author_name, '') as public_species,
				sat.association_type_name as public_association_type_name,
				sa_genera.genus_name || ' ' || sa_species.species || ' ' || coalesce(sa_authors.author_name, '') as public_association_species,
				cn.common_name as public_common_name,
				l.language_name_english as public_language_name
			  from public.tbl_taxa_tree_master t
			  join public.tbl_taxa_tree_genera g
			   on t.genus_id = g.genus_id
			  join public.tbl_taxa_tree_families f
			   on g.family_id = f.family_id
			  join public.tbl_taxa_tree_orders o
			   on o.order_id = f.order_id
			  left join public.tbl_taxa_tree_authors a
			   on t.author_id = a.author_id
			  -- associations
			  left join public.tbl_species_associations sa
			   on t.taxon_id = sa.taxon_id
			  left join public.tbl_species_association_types sat
			   on sat.association_type_id = sa.association_type_id
			  left join public.tbl_taxa_tree_master sa_species
			   on sa.associated_taxon_id = sa_species.taxon_id
			  left join public.tbl_taxa_tree_genera sa_genera
			   on sa_species.genus_id = sa_genera.genus_id
			  left join public.tbl_taxa_tree_authors sa_authors
			   on sa_species.author_id = sa_authors.author_id
			  -- // end associations
			  --common names
			  left join public.tbl_taxa_common_names cn
			   on cn.taxon_id = t.taxon_id
			  left join public.tbl_languages l
			   on cn.language_id = l.language_id
			   -- // end common names

		) As RDB
		  On RDB.taxon_id = LDB.public_db_id
		Where LDB.source_id = 1
		  And LDB.submission_id = $1
		Order By LDB.species;
End $$ Language plpgsql;
/*****************************************************************************************************************************
**	Function	fn_clearinghouse_report_taxa_other_lists
**	Who			Erik Eriksson
**	When		2013-11-21
**	What		Displays taxa data for uploaded species, together with associations and common names
**	Uses
**	Used By
**	Revisions
******************************************************************************************************************************/
-- Drop Function clearing_house.fn_clearinghouse_report_taxa_other_lists(int)
-- Select * From clearing_house.fn_clearinghouse_report_taxa_other_lists(2)
Create Or Replace Function clearing_house.fn_clearinghouse_report_taxa_other_lists(int)
Returns Table (

	local_db_id int,

	species text,
	distribution_text text,
	distribution_reference text,
	biology_text text,
	biology_reference text,
	taxonomy_note_text text,
	taxonomy_note_reference text,
	identification_key_text text,
	identification_key_reference text,

	public_db_id int,

    public_species text,
	public_distribution_text text,
	public_distribution_reference text,
	public_biology_text text,
	public_biology_reference text,
	public_taxonomy_note_text text,
	public_taxonomy_note_reference text,
	public_identification_key_text text,
	public_identification_key_reference text,

    date_updated text,
	entity_type_id int

) As $$

Declare
    entity_type_id int;

Begin

    entity_type_id := clearing_house.fn_get_entity_type_for('tbl_taxa_tree_master ');

	Return Query

		Select
			LDB.local_db_id                            	As local_db_id,
			LDB.species,
			LDB.distribution_text,
			LDB.distribution_reference,
			LDB.biology_text,
			LDB.biology_reference,
			LDB.taxonomy_note_text,
			LDB.taxonomy_note_reference,
			LDB.identification_key_text,
			LDB.identification_key_reference,

  			LDB.public_db_id                            As public_db_id,

            RDB.public_species,
			RDB.public_distribution_text,
			RDB.public_distribution_reference,
			RDB.public_biology_text,
			RDB.public_biology_reference,
			RDB.public_taxonomy_note_text,
			RDB.public_taxonomy_note_reference,
			RDB.public_identification_key_text,
			RDB.public_identification_key_reference,


			to_char(LDB.date_updated,'YYYY-MM-DD')		As date_updated,
			entity_type_id              				As entity_type_id

		From (

			select t.submission_id,
				t.source_id,
				t.taxon_id As local_db_id,
				t.public_db_id As public_db_id,
				g.genus_name || ' ' || t.species || ' ' || coalesce(a.author_name, '')	As species,
				d.distribution_text,
				db.authors || '(' || db.year || ')' as distribution_reference,
				b.biology_text,
				bb.authors || '(' || bb.year || ')' as biology_reference,
				n.taxonomy_notes as taxonomy_note_text,
				nb.authors || '(' || nb.year || ')' as taxonomy_note_reference,
				ik.key_text as identification_key_text,
				ikb.authors || '(' || ikb.year || ')' as identification_key_reference,
				t.date_updated
			  from clearing_house.view_taxa_tree_master t
			  join clearing_house.view_taxa_tree_genera g
			   on t.genus_id = g.merged_db_id
			   and g.submission_id in (0, t.submission_id)
			  left join clearing_house.view_taxa_tree_authors a
			   on t.author_id = a.merged_db_id
			   And a.submission_id in (0, t.submission_id)
			  --distribution
			  left join clearing_house.view_text_distribution d
			   on d.taxon_id = t.merged_db_id
			   And d.submission_id in (0, t.submission_id)
			  left Join clearing_house.view_biblio db
			   On db.merged_db_id = d.biblio_id
			   And db.submission_id in (0, t.submission_id)
			  --text biology
			  left join clearing_house.view_text_biology b
			   on b.taxon_id = t.merged_db_id
			   And b.submission_id in (0, t.submission_id)
			  left join clearing_house.view_biblio bb
			   on b.biblio_id = bb.merged_db_id
			   And bb.submission_id in (0, t.submission_id)
			  --taxonomy notes
			  left join clearing_house.view_taxonomy_notes n
			   on n.taxon_id = t.merged_db_id
			   And n.submission_id in (0, t.submission_id)
			  left join clearing_house.view_biblio nb
			   on n.biblio_id = nb.merged_db_id
			   And nb.submission_id in (0, t.submission_id)
			  --identification keys
			  left join clearing_house.view_text_identification_keys ik
			   on ik.taxon_id = t.merged_db_id
			   And ik.submission_id in (0, t.submission_id)
			  left join clearing_house.view_biblio ikb
			   on ik.biblio_id = ikb.merged_db_id
			   And ikb.submission_id in (0, t.submission_id)

		) As LDB Left Join (
				select
				t.taxon_id As taxon_id,
				g.genus_name || ' ' || t.species || ' ' || coalesce(a.author_name, '')	As public_species,
				d.distribution_text as public_distribution_text,
				db.authors || '(' || db.year || ')' as public_distribution_reference,
				b.biology_text as public_biology_text,
				bb.authors || '(' || bb.year || ')' as public_biology_reference,
				n.taxonomy_notes as public_taxonomy_note_text,
				nb.authors || '(' || nb.year || ')' as public_taxonomy_note_reference,
				ik.key_text as public_identification_key_text,
				ikb.authors || '(' || ikb.year || ')' as public_identification_key_reference,
				t.date_updated
			  from public.tbl_taxa_tree_master t
			  join public.tbl_taxa_tree_genera g
			   on t.genus_id = g.genus_id
			  left join public.tbl_taxa_tree_authors a
			   on t.author_id = a.author_id
			  --distribution
			  left join public.tbl_text_distribution d
			   on d.taxon_id = t.taxon_id
			  left Join public.tbl_biblio db
			   On db.biblio_id = d.biblio_id
			  --text biology
			  left join public.tbl_text_biology b
			   on b.taxon_id = t.taxon_id
			  left join public.tbl_biblio bb
			   on b.biblio_id = bb.biblio_id
			  --taxonomy notes
			  left join public.tbl_taxonomy_notes n
			   on n.taxon_id = t.taxon_id
			  left join public.tbl_biblio nb
			   on n.biblio_id = nb.biblio_id
			  --identification keys
			  left join public.tbl_text_identification_keys ik
			   on ik.taxon_id = t.taxon_id
			  left join public.tbl_biblio ikb
			   on ik.biblio_id = ikb.biblio_id

		) As RDB
		  On RDB.taxon_id = LDB.public_db_id
		Where LDB.source_id = 1
		  And LDB.submission_id = $1
		Order By LDB.species;
End $$ Language plpgsql;
/*****************************************************************************************************************************
**	Function	fn_clearinghouse_report_taxa_seasonality
**	Who			Erik Eriksson
**	When		2013-11-21
**	What		Displays taxa seasonality data
**	Uses
**	Used By
**	Revisions
******************************************************************************************************************************/
-- Drop Function clearing_house.fn_clearinghouse_report_taxa_seasonality(int)
-- Select * From clearing_house.fn_clearinghouse_report_taxa_seasonality(2)
Create Or Replace Function clearing_house.fn_clearinghouse_report_taxa_seasonality(int)
Returns Table (

	local_db_id int,

	species text,
	season_name character varying,
	season_type character varying,
	location_name character varying,
	activity_type character varying,

	public_db_id int,

	public_species text,
	public_season_name character varying,
	public_season_type character varying,
	public_location_name character varying,
	public_activity_type character varying,

	date_updated text,
	entity_type_id int

) As $$

Declare
    entity_type_id int;

Begin

    entity_type_id := clearing_house.fn_get_entity_type_for('tbl_taxa_seasonality ');

	Return Query

		Select
			LDB.local_db_id                             As local_db_id,
			LDB.species                                 As species,
			LDB.season_name                             As season_name,
			LDB.season_type                             As season_type,
			LDB.location_name                           As location_name,
			LDB.activity_type                           As activity_type,

			LDB.public_db_id                            As public_db_id,

			RDB.public_species                          As public_species,
			RDB.public_season_name                      As public_season_name,
			RDB.public_season_type                      As public_season_type,
			RDB.public_location_name                    As public_location_name,
			RDB.public_activity_type                    As public_activity_type,

			to_char(LDB.date_updated,'YYYY-MM-DD')		As date_updated,
            entity_type_id                                  As entity_type_id

		From (
			select t.submission_id,
			   t.source_id,
			   t.taxon_id As local_db_id,
			   t.public_db_id As public_db_id,
			   g.genus_name || ' ' || t.species || ' ' || coalesce(a.author_name, '')	As species,
			   s.season_name,
			   st.season_type,
			   l.location_name,
			   at.activity_type,
			   t.date_updated
			 from clearing_house.view_taxa_tree_master t
			 join clearing_house.view_taxa_tree_genera g
			  on t.genus_id = g.merged_db_id
			  and g.submission_id in (0, t.submission_id)
			 left join clearing_house.view_taxa_tree_authors a
			  on t.author_id = a.merged_db_id
			  And a.submission_id in (0, t.submission_id)
			left join clearing_house.view_taxa_seasonality ts
			  on ts.merged_db_id = t.taxon_id
			  and ts.submission_id in (0, t.submission_id)
			join clearing_house.view_seasons s
			  on ts.season_id = s.merged_db_id
			  and s.submission_id in (0, t.submission_id)
			join clearing_house.view_season_types st
			  on s.season_type_id = st.merged_db_id
			  and st.submission_id in (0, t.submission_id)
			join clearing_house.view_activity_types at
			  on ts.activity_type_id = at.merged_db_id
			  and at.submission_id in (0, t.submission_id)
			join clearing_house.view_locations l
			  on ts.location_id = l.merged_db_id
			  and l.submission_id in (0, t.submission_id)

		) As LDB Left Join (
            select
               t.taxon_id As taxon_id,
               g.genus_name || ' ' || t.species || ' ' || coalesce(a.author_name, '')	As public_species,
               s.season_name as public_season_name,
               st.season_type as public_season_type,
               l.location_name as public_location_name,
               at.activity_type as public_activity_type,
               t.date_updated
            from public.tbl_taxa_tree_master t
            join public.tbl_taxa_tree_genera g
              on t.genus_id = g.genus_id
             left join public.tbl_taxa_tree_authors a
              on t.author_id = a.author_id
            left join public.tbl_taxa_seasonality ts
              on ts.taxon_id = t.taxon_id
            join public.tbl_seasons s
              on ts.season_id = s.season_id
            join public.tbl_season_types st
              on s.season_type_id = st.season_type_id
            join public.tbl_activity_types at
              on ts.activity_type_id = at.activity_type_id
            join public.tbl_locations l
              on ts.location_id = l.location_id
		) As RDB
		  On RDB.taxon_id = LDB.public_db_id
		Where LDB.source_id = 1
		  And LDB.submission_id = $1
		Order By LDB.species;
End $$ Language plpgsql;

/*****************************************************************************************************************************
**	Function	fn_clearinghouse_report_relative_ages
**	Who			Roger Mähler
**	When		2013-11-21
**	What		Displays relative ages data
**	Uses
**	Used By
**	Revisions
******************************************************************************************************************************/
-- Drop Function clearing_house.fn_clearinghouse_report_relative_ages(int);
-- Select count(*) From clearing_house.fn_clearinghouse_report_relative_ages(2);
Create Or Replace Function clearing_house.fn_clearinghouse_report_relative_ages(int)
Returns Table (

	local_db_id int,

    sample_name					character varying,
    abbreviation				character varying,
    location_name				character varying,
    uncertainty					character varying,
    method_name					character varying,
    C14_age_older				numeric(20,5),
    C14_age_younger				numeric(20,5),
    CAL_age_older				numeric(20,5),
    CAL_age_younger				numeric(20,5),
    relative_age_name			character varying,
    notes						text,
    date_notes                  text,
    reference					text,

	public_db_id				int,

    public_sample_name			character varying,
    public_abbreviation			character varying,
    public_location_name		character varying,
    public_uncertainty 			character varying,
    public_method_name 			character varying,
    public_C14_age_older 		numeric(20,5),
    public_C14_age_younger 		numeric(20,5),
    public_CAL_age_older 		numeric(20,5),
    public_CAL_age_younger 		numeric(20,5),
    public_relative_age_name	character varying,
    public_notes 				text,
    public_date_notes           text,
    public_reference 			text,

	date_updated				text,
	entity_type_id				int

) As $$

Declare
    entity_type_id int;

Begin

    entity_type_id := clearing_house.fn_get_entity_type_for('tbl_relative_ages ');

	Return Query

		Select

			LDB.local_db_id                             			As local_db_id,

            LDB.sample_name		                                 	As sample_name,
            LDB.abbreviation		                                As abbreviation,
            LDB.location_name		                                As location_name,
            LDB.uncertainty		                                 	As uncertainty,
            LDB.method_name		                                 	As method_name,
            LDB.C14_age_older		                                As C14_age_older,
            LDB.C14_age_younger		                                As C14_age_younger,
            LDB.CAL_age_older		                                As CAL_age_older,
            LDB.CAL_age_younger		                                As CAL_age_younger,
            LDB.relative_age_name		                            As relative_age_name,
            LDB.notes		                                 		As notes,
            LDB.date_notes	                                 		As date_notes,
            LDB.reference		                                 	As reference,

			LDB.public_db_id                            			As public_db_id,

            RDB.sample_name		                                 	As public_sample_name,
            RDB.abbreviation		                                As public_abbreviation,
            RDB.location_name		                                As public_location_name,
            RDB.uncertainty		                                 	As public_uncertainty,
            RDB.method_name		                                 	As public_method_name,
            RDB.C14_age_older		                                As public_C14_age_older,
            RDB.C14_age_younger		                                As public_C14_age_younger,
            RDB.CAL_age_older		                                As public_CAL_age_older,
            RDB.CAL_age_younger		                                As public_CAL_age_younger,
            RDB.relative_age_name		                            As public_relative_age_name,
            RDB.notes		                                 		As public_notes,
            RDB.date_notes	                                 		As public_date_notes,
            RDB.reference		                                 	As public_reference,

			to_char(LDB.date_updated,'YYYY-MM-DD')					As date_updated,
            entity_type_id                             				As entity_type_id

		From (

			select  ra.submission_id								As submission_id,
                    ra.source_id									As source_id,
                    ra.relative_age_id								As local_db_id,
                    ra.public_db_id									As public_db_id,

                    ps.sample_name                                 	As sample_name,
                    ''::character varying              				As abbreviation, /* NOTE! Missing in development schema */
                    l.location_name									As location_name,
                    du.uncertainty									As uncertainty,
                    m.method_name									As method_name,
                    ra.C14_age_older								As C14_age_older,
                    ra.C14_age_younger								As C14_age_younger,
                    ra.CAL_age_older								As CAL_age_older,
                    ra.CAL_age_younger								As CAL_age_younger,
                    ra.relative_age_name							As relative_age_name,
                    ra.notes										As notes,
                    rd.notes							            As date_notes,
                    b.full_reference                        		As reference,
                    rd.date_updated									As date_updated

            From clearing_house.view_relative_dates rd
            Join clearing_house.view_relative_ages ra
              On ra.merged_db_id = rd.relative_age_id
             And ra.submission_id In (0, rd.submission_id)
            Join clearing_house.view_relative_age_types rat
              On rat.merged_db_id = ra.relative_age_type_id
             And rat.submission_id In (0, rd.submission_id)
            Left Join clearing_house.view_dating_uncertainty du
              On du.merged_db_id = rd.dating_uncertainty_id
             And du.submission_id In (0, rd.submission_id)
            /* bibliographic entries */
            Left Join clearing_house.view_relative_age_refs raf
              On raf.relative_age_id = ra.merged_db_id
             And raf.submission_id In (0, rd.submission_id)
            Left Join clearing_house.view_biblio b
              On b.merged_db_id = raf.biblio_id
             And b.submission_id In (0, raf.submission_id)
            /* Locations */
            Left Join clearing_house.view_locations l
              On l.merged_db_id = ra.location_id
             And l.submission_id In (0, rd.submission_id)
            /* Physical sample & method */
            Join clearing_house.view_analysis_entities ae
              On ae.merged_db_id = rd.analysis_entity_id
             And ae.submission_id In (0, rd.submission_id)
            Join clearing_house.view_physical_samples ps
              On ps.merged_db_id = ae.physical_sample_id
             And ps.submission_id In (0, rd.submission_id)
            Join clearing_house.view_methods m
              On m.merged_db_id = rd.method_id
             And m.submission_id In (0, rd.submission_id)

		) As LDB
        Left Join (

           Select 	ra.relative_age_id								As relative_age_id,
					ps.sample_name									As sample_name,
                    ra.abbreviation          						As abbreviation,
                    l.location_name									As location_name,
                    du.uncertainty									As uncertainty,
                    m.method_name									As method_name,
                    ra.C14_age_older								As C14_age_older,
                    ra.C14_age_younger								As C14_age_younger,
                    ra.CAL_age_older								As CAL_age_older,
                    ra.CAL_age_younger								As CAL_age_younger,
                    ra.relative_age_name							As relative_age_name,
                    ra.notes										As notes,
                    rd.notes										As date_notes,
                    b.full_reference                        		As reference
            From public.tbl_relative_dates rd
            Join public.tbl_relative_ages ra
              On ra.relative_age_id = rd.relative_age_id
            Join public.tbl_relative_age_types rat
              On rat.relative_age_type_id = ra.relative_age_type_id
            Left Join public.tbl_dating_uncertainty du
              On du.dating_uncertainty_id = rd.dating_uncertainty_id
            /* bibliographic entries 1:0-n */
            Left Join public.tbl_relative_age_refs raf
              On raf.relative_age_id = ra.relative_age_id
            Left Join public.tbl_biblio b
              On b.biblio_id = raf.biblio_id
            /* Locations: 1:0-1 */
            Left Join public.tbl_locations l
              On l.location_id = ra.location_id
            /* Physical sample & method */
            Join public.tbl_analysis_entities ae
              On ae.analysis_entity_id  = rd.analysis_entity_id
            Join public.tbl_physical_samples ps
              On ps.physical_sample_id  = ae.physical_sample_id
            Join public.tbl_methods m
              On m.method_id = rd.method_id

		) As RDB
		  On RDB.relative_age_id = LDB.public_db_id
		Where LDB.source_id = 1
		  And LDB.submission_id = $1
		Order By LDB.sample_name;

End $$ Language plpgsql;

/*****************************************************************************************************************************
**	Function	fn_clearinghouse_report_datasets
**	Who			Roger Mähler
**	When		2013-11-21
**	What		Displays submission datasets data
**	Uses
**	Used By
**	Revisions	2014-03-18 Bug fix in LDB data
**					rt.merged_db_id = rt.record_type_id changed to rt.merged_db_id = m.record_type_id
******************************************************************************************************************************/
-- Select * From clearing_house.fn_clearinghouse_report_datasets(32)
Create Or Replace Function clearing_house.fn_clearinghouse_report_datasets(int)
Returns Table (

	local_db_id int,

    dataset_name                        character varying,
    method_name                         character varying,
    method_abbrev_or_alt_name           character varying,
    description                         text,
    record_type_name                    character varying,

	public_db_id                        int,

    public_dataset_name                 character varying,
    public_method_name                  character varying,
    public_method_abbrev_or_alt_name	character varying,
    public_description					text,
    public_record_type_name             character varying,

	date_updated                        text,
	entity_type_id                      int

) As $$

Declare
    entity_type_id int;

Begin

    entity_type_id := clearing_house.fn_get_entity_type_for('tbl_datasets ');

	Return Query

		Select

			LDB.local_db_id                             			As local_db_id,

            LDB.dataset_name		                                As dataset_name,
            LDB.method_name                                         As method_name,
            LDB.method_abbrev_or_alt_name		                    As method_abbrev_or_alt_name,
            LDB.description		                                 	As description,
            LDB.record_type_name		                            As record_type_name,

			LDB.public_db_id                            			As public_db_id,

            RDB.dataset_name		                                As public_dataset_name,
            RDB.method_name                                         As public_method_name,
            RDB.method_abbrev_or_alt_name		                    As public_method_abbrev_or_alt_name,
            RDB.description		                                 	As public_description,
            RDB.record_type_name		                            As public_record_type_name,

			to_char(LDB.date_updated,'YYYY-MM-DD')					As date_updated,
            entity_type_id                             				As entity_type_id

		From (

			Select  d.submission_id                                 As submission_id,
                    d.source_id                                     As source_id,
                    d.local_db_id									As local_db_id,
                    d.public_db_id									As public_db_id,
                    d.dataset_name                                  As dataset_name,
                    m.method_name                                   As method_name,
                    m.method_abbrev_or_alt_name                     As method_abbrev_or_alt_name,
                    m.description                                   As description,
                    rt.record_type_name                             As record_type_name,
                    d.date_updated                                 As date_updated
            From clearing_house.view_datasets d
            Left Join clearing_house.view_methods m
              On m.merged_db_id = d.method_id
             And m.submission_id In (0, d.submission_id)
            Left Join clearing_house.view_record_types rt
              On rt.merged_db_id = m.record_type_id
             And rt.submission_id In (0, d.submission_id)

		) As LDB Left Join (

            select  d.dataset_id                                    As dataset_id,
                    d.dataset_name                                  As dataset_name,
                    m.method_name                                   As method_name,
                    m.method_abbrev_or_alt_name                     As method_abbrev_or_alt_name,
                    m.description                                   As description,
                    rt.record_type_name                             As record_type_name
            from public.tbl_datasets d
            left join public.tbl_methods m
              on d.method_id = m.method_id
            left join public.tbl_record_types rt
              on m.record_type_id = rt.record_type_id
            /*
            join ( -- Unique relation dataset -> sites (om sites data ska tas med)
                select distinct d.dataset_id, s.site_id
                from public.tbl_datasets d
                left join public.tbl_analysis_entities ae
                  on ae.dataset_id = d.dataset_id
                join public.tbl_physical_samples ps
                  on ae.physical_sample_id = ps.physical_sample_id
                left join public.tbl_sample_groups sg
                  on ps.sample_group_id = sg.sample_group_id
                join public.tbl_sites s
                  on sg.site_id = s.site_id
            ) as ds
              on ds.dataset_id =  d.dataset_id
            */

		) As RDB
		  On RDB.dataset_id = LDB.public_db_id
		Where LDB.source_id = 1
		  And LDB.submission_id = $1
		Order By LDB.dataset_name;

End $$ Language plpgsql;


/*****************************************************************************************************************************
**	Function	fn_clearinghouse_report_methods
**	Who			Roger Mähler
**	When		2013-11-21
**	What		Displays submission methods data
**	Uses
**	Used By
**	Revisions
******************************************************************************************************************************/
-- Select * From clearing_house.fn_clearinghouse_report_methods(2)
Create Or Replace Function clearing_house.fn_clearinghouse_report_methods(int)
Returns Table (

	local_db_id int,

    method_name                         character varying,
    method_abbrev_or_alt_name           character varying,
    description                         text,
    record_type_name                    character varying,
	group_name                    		character varying,
    group_description                   text,
    unit_name                    		character varying,

	public_db_id                        int,

    public_method_name                  character varying,
    public_method_abbrev_or_alt_name    character varying,
    public_description                  text,
    public_record_type_name             character varying,
	public_group_name                   character varying,
    public_group_description            text,
    public_unit_name                    character varying,

	date_updated                        text,
	entity_type_id                      int

) As $$

Declare
    entity_type_id int;

Begin

    entity_type_id := clearing_house.fn_get_entity_type_for('tbl_datasets ');

	Return Query

		Select

			LDB.local_db_id                             			As local_db_id,

            LDB.method_name                                         As method_name,
            LDB.method_abbrev_or_alt_name		                    As method_abbrev_or_alt_name,
            LDB.description		                                 	As description,
            LDB.record_type_name		                            As record_type_name,
            LDB.group_name		                           			As group_name,
            LDB.group_description		                            As group_description,
            LDB.unit_name		                            		As unit_name,

			LDB.public_db_id                            			As public_db_id,

            RDB.method_name                                         As method_name,
            RDB.method_abbrev_or_alt_name		                    As method_abbrev_or_alt_name,
            RDB.description		                                 	As description,
            RDB.record_type_name		                            As record_type_name,
            RDB.group_name		                           			As group_name,
            RDB.group_description		                            As group_description,
            RDB.unit_name		                            		As unit_name,

			to_char(LDB.date_updated,'YYYY-MM-DD')					As date_updated,
            entity_type_id                             				As entity_type_id

		From (

			Select  m.submission_id                                 As submission_id,
                    m.source_id                                     As source_id,
                    m.local_db_id									As local_db_id,
                    m.public_db_id									As public_db_id,
					m.method_name                                   As method_name,
					m.method_abbrev_or_alt_name                     As method_abbrev_or_alt_name,
					m.description                                   As description,
					rt.record_type_name                             As record_type_name,
					mg.group_name									As group_name,
					mg.description									As group_description,
					u.unit_name										As unit_name,
					m.date_updated									As date_updated
			From clearing_house.view_methods m
			Left Join clearing_house.view_record_types rt
			  on rt.merged_db_id = m.record_type_id
			 And rt.submission_id In (0, m.submission_id)
			Left Join clearing_house.view_method_groups mg
			  on mg.merged_db_id = m.method_group_id
			 And mg.submission_id In (0, m.submission_id)
			Left Join clearing_house.view_units u
			  On u.merged_db_id = m.unit_id
			 And u.submission_id In (0, m.submission_id)


		) As LDB Left Join (

			select  m.method_id                                    	As method_id,
					m.method_name                                   As method_name,
					m.method_abbrev_or_alt_name                     As method_abbrev_or_alt_name,
					m.description                                   As description,
					rt.record_type_name                             As record_type_name,
					mg.group_name									As group_name,
					mg.description									As group_description,
					u.unit_name										As unit_name
			from public.tbl_methods m
			left join public.tbl_record_types rt
			  on m.record_type_id = rt.record_type_id
			left join public.tbl_method_groups mg
			  on mg.method_group_id = m.method_group_id
			left join public.tbl_units u
			  on u.unit_id = m.unit_id
		) As RDB
		  On RDB.method_id = LDB.public_db_id
		Where LDB.source_id = 1
		  And LDB.submission_id = $1
		Order By LDB.method_name;

End $$ Language plpgsql;

/*****************************************************************************************************************************
**	Function	fn_clearinghouse_latest_accepted_sites
**	Who			Roger Mähler
**	When		2013-12-11
**	What
**	Uses
**	Used By
**	Revisions
******************************************************************************************************************************/
-- Select * From clearing_house.fn_clearinghouse_latest_accepted_sites()
Create Or Replace Function clearing_house.fn_clearinghouse_latest_accepted_sites()
Returns Table (
    last_updated_sites text
) As $$
Begin
	Return Query
		Select site
		From (
			Select Distinct s.site_name || ', ' || d.dataset_name || ', ' || m.method_name as site, d.date_updated
			From public.tbl_datasets d
			Join public.tbl_analysis_entities ae
			  On ae.dataset_id = d.dataset_id
			Join public.tbl_physical_samples ps
			  On ps.physical_sample_id = ae.physical_sample_id
			Join public.tbl_sample_groups sg
			  On sg.sample_group_id = ps.sample_group_id
			Join public.tbl_sites s
			  On s.site_id = sg.site_id
			Join public.tbl_methods m
			  On m.method_id = d.method_id
			Order By d.date_updated Desc
			Limit 10
		) as x;

End $$ Language plpgsql;
/*****************************************************************************************************************************
**	Function	fn_clearinghouse_info_references
**	Who			Roger Mähler
**	When		2013-12-11
**	What
**	Uses
**	Used By
**	Revisions
******************************************************************************************************************************/
-- Drop Function clearing_house.fn_clearinghouse_info_references()
-- Select * From clearing_house.fn_clearinghouse_info_references()
Create Or Replace Function clearing_house.fn_clearinghouse_info_references()
Returns Table (
    info_reference_id int,
    info_reference_type character varying,
    display_name  character varying,
    href  character varying
) As $$
Begin
	Return Query
		Select x.info_reference_id, x.info_reference_type, x.display_name, x.href
        From clearing_house.tbl_clearinghouse_info_references x
        Order By 1;

End $$ Language plpgsql;

/*****************************************************************************************************************************
**	Function	fn_clearinghouse_report_feature_types
**	Who			Roger Mähler
**	When		2018-03-29
**	What		Displays feature types data
**	Uses
**	Used By
**	Revisions
******************************************************************************************************************************/
-- Drop Function clearing_house.fn_clearinghouse_report_feature_types(int);
-- Select * From clearing_house.fn_clearinghouse_report_feature_types(1)
Create Or Replace Function clearing_house.fn_clearinghouse_report_feature_types(int)
Returns Table (
	local_db_id                         int,
    type_name                           character varying,
    description                         text,
	public_db_id                        int,
    public_type_name                    character varying,
    public_description                  text,
	date_updated                        text,
	entity_type_id                      int
) As $$

Declare
    entity_type_id int;
Begin

    entity_type_id := clearing_house.fn_get_entity_type_for('tbl_feature_types');

	Return Query

        Select
            LDB.local_db_id                       	As local_db_id,
            LDB.type_name                           As type_name,
            LDB.description		                    As description,
            LDB.public_db_id                        As public_db_id,
            RDB.type_name                           As public_type_name,
            RDB.description		                    As public_description,
            to_char(LDB.date_updated,'YYYY-MM-DD')	As date_updated,
            entity_type_id                          As entity_type_id

        From (

            Select
                ft.submission_id                    As submission_id,
                ft.source_id                        As source_id,
                ft.local_db_id					    As local_db_id,
                ft.public_db_id					    As public_db_id,
                ft.feature_type_name                As type_name,
                ft.feature_type_description		    As description,
                ft.date_updated					    As date_updated

            From clearing_house.view_feature_types ft

        ) As LDB

        Left Join (

            Select
                ft.feature_type_id                  As feature_type_id,
                ft.feature_type_name                As type_name,
                ft.feature_type_description		    As description

            From public.tbl_feature_types ft

        ) As RDB
          On RDB.feature_type_id = LDB.public_db_id

        Where LDB.source_id = 1
          And LDB.submission_id = $1
        Order By LDB.type_name;

End $$ Language plpgsql;

/*****************************************************************************************************************************
**	Function	fn_clearinghouse_report_sample_group_dimensions
**	Who			Roger Mähler
**	When		2018-03-29
**	What		Displays sample group dimensions
**	Uses
**	Used By
**	Revisions
******************************************************************************************************************************/
-- Select * From clearing_house.fn_clearinghouse_report_sample_group_dimensions(1)
Create Or Replace Function clearing_house.fn_clearinghouse_report_sample_group_dimensions(int)
Returns Table (
	local_db_id                         int,
	sample_group_id                     int,
    sample_group_name                   character varying,
    dimension_name                      character varying,
    dimension_value                     numeric(20,5),

	public_db_id                        int,
	public_sample_group_id              int,
    public_sample_group_name            character varying,
    public_dimension_name               character varying,
    public_dimension_value              numeric(20,5),

	date_updated                        text,
	entity_type_id                      int
) As $$

Declare
    entity_type_id int;
Begin

    entity_type_id := clearing_house.fn_get_entity_type_for('tbl_sample_group_dimensions');

	Return Query


        Select
            LDB.local_db_id						            As local_db_id,
            LDB.sample_group_id					           	As sample_group_id,
            LDB.sample_group_name							As sample_group_name,
            LDB.dimension_name								As dimension_name,
            LDB.dimension_value								As dimension_value,

            LDB.public_db_id						        As public_db_id,
            RDB.sample_group_id						        As public_sample_group_id,
            RDB.sample_group_name							As public_sample_group_name,
            RDB.dimension_name								As public_dimension_name,
            RDB.dimension_value								As public_dimension_value,

            to_char(LDB.date_updated,'YYYY-MM-DD')			As date_updated,
            entity_type_id						            As entity_type_id

        From (

            Select	sgd.submission_id				        As submission_id,
                    sgd.source_id					        As source_id,
                    sgd.local_db_id				            As local_db_id,
                    sgd.public_db_id				        As public_db_id,
                    sgd.sample_group_id			            As sample_group_id,
                    sgd.dimension_value			            As dimension_value,
                    sgd.date_updated				        As date_updated,
                    sg.sample_group_name			        As sample_group_name,
                    d.dimension_name				        As dimension_name

            From clearing_house.view_sample_group_dimensions sgd
            Join clearing_house.view_dimensions d
              On d.merged_db_id = sgd.dimension_id
             And d.submission_id In (0, sgd.submission_id)
            Join clearing_house.view_sample_groups sg
              On sg.merged_db_id = sgd.sample_group_id
             And sg.submission_id In (0, sgd.submission_id)

        ) As LDB

        Left Join (

            Select 	sgd.sample_group_id				        As sample_group_id,
                    sgd.dimension_value				        As dimension_value,
                    sg.sample_group_name				    As sample_group_name,
                    d.dimension_name					    As dimension_name

            From public.tbl_sample_group_dimensions as sgd
            Join public.tbl_dimensions d
              On sgd.dimension_id = d.dimension_id
            Join public.tbl_sample_groups sg
              On sg.sample_group_id = sgd.sample_group_id

        ) as RDB
          On RDB.sample_group_id = LDB.public_db_id

        Where LDB.source_id = 1
          And LDB.submission_id = $1

        Order by LDB.sample_group_id;

End $$ Language plpgsql;

/*****************************************************************************************************************************
**	Function	fn_clearinghouse_report_sample_dimensions
**	Who			Roger Mähler
**	When		2018-03-29
**	What		Displays sample dimensions
**	Uses
**	Used By
**	Revisions
******************************************************************************************************************************/
-- Drop Function clearing_house.fn_clearinghouse_report_sample_dimensions(int);
-- Select * From clearing_house.fn_clearinghouse_report_sample_dimensions(1)
Create Or Replace Function clearing_house.fn_clearinghouse_report_sample_dimensions(int)
Returns Table (
	local_db_id                         int,
	physical_sample_id                  int,
    sample_name                         character varying,
    dimension_name                      character varying,
    dimension_value                     numeric(20,5),

	public_db_id                        int,
	public_physical_sample_id           int,
    public_sample_name                  character varying,
    public_dimension_name               character varying,
    public_dimension_value              numeric(20,5),

	date_updated                        text,
	entity_type_id                      int
) As $$

Declare
    entity_type_id int;
Begin

    entity_type_id := clearing_house.fn_get_entity_type_for('tbl_sample_dimensions');

	Return Query

        Select
            LDB.local_db_id						            As local_db_id,
            LDB.physical_sample_id					        As physical_sample_id,
            LDB.sample_name							        As sample_name,
            LDB.dimension_name								As dimension_name,
            LDB.dimension_value								As dimension_value,

            LDB.public_db_id						        As public_db_id,
            RDB.physical_sample_id						    As public_physical_sample_id,
            RDB.sample_name							        As public_sample_name,
            RDB.dimension_name								As public_dimension_name,
            RDB.dimension_value								As public_dimension_value,

            to_char(LDB.date_updated,'YYYY-MM-DD')			As date_updated,
            entity_type_id						            As entity_type_id

        From (

            Select	sd.submission_id				        As submission_id,
                    sd.source_id					        As source_id,
                    sd.local_db_id				            As local_db_id,
                    sd.public_db_id				            As public_db_id,
                    ps.physical_sample_id                   As physical_sample_id,
                    ps.sample_name			                As sample_name,
                    d.dimension_name				        As dimension_name,
                    sd.dimension_value			            As dimension_value,
                    sd.date_updated				            As date_updated

            From clearing_house.view_sample_dimensions sd
            Join clearing_house.view_dimensions d
              On d.merged_db_id = sd.dimension_id
             And d.submission_id In (0, sd.submission_id)
            Join clearing_house.view_physical_samples ps
              On ps.merged_db_id = sd.physical_sample_id
             And ps.submission_id In (0, sd.submission_id)

        ) As LDB

        Left Join (

            Select 	sd.sample_dimension_id                  As sample_dimension_id,
                    ps.physical_sample_id				    As physical_sample_id,
                    ps.sample_name				            As sample_name,
                    d.dimension_name					    As dimension_name,
                    sd.dimension_value				        As dimension_value
            From public.tbl_sample_dimensions sd
            Join public.tbl_dimensions d
              On d.dimension_id = sd.dimension_id
            Join public.tbl_physical_samples ps
              On ps.physical_sample_id = sd.physical_sample_id

        ) as RDB
          On RDB.sample_dimension_id = LDB.public_db_id

        Where LDB.source_id = 1
          And LDB.submission_id = $1

        Order by LDB.physical_sample_id;

End $$ Language plpgsql;

/*****************************************************************************************************************************
**	Function	fn_clearinghouse_report_sample_descriptions
**	Who			Roger Mähler
**	When		2018-03-29
**	What		Displays sample descriptions
**	Uses
**	Used By
**	Revisions
******************************************************************************************************************************/
-- Drop Function clearing_house.fn_clearinghouse_report_sample_descriptions(int);
-- Select * From clearing_house.fn_clearinghouse_report_sample_descriptions(1)
CREATE OR REPLACE FUNCTION clearing_house.fn_clearinghouse_report_sample_descriptions(
	integer)
RETURNS TABLE(local_db_id integer, physical_sample_id integer, sample_name character varying, type_name character varying, description character varying, public_db_id integer, public_physical_sample_id integer, public_sample_name character varying, public_type_name character varying, public_description character varying, date_updated text, entity_type_id integer)
    LANGUAGE 'plpgsql'
AS $BODY$

Declare
    entity_type_id int;
Begin

    entity_type_id := clearing_house.fn_get_entity_type_for('tbl_sample_descriptions');

	Return Query

        Select
            LDB.local_db_id						            As local_db_id,
            LDB.physical_sample_id					        As physical_sample_id,
            LDB.sample_name							        As sample_name,
            LDB.type_name								    As type_name,
            LDB.description								    As description,

            LDB.public_db_id						        As public_db_id,
            RDB.physical_sample_id						    As public_physical_sample_id,
            RDB.sample_name							        As public_sample_name,
            RDB.type_name								    As public_type_name,
            RDB.description								    As public_description,

            to_char(LDB.date_updated,'YYYY-MM-DD')			As date_updated,
            entity_type_id						            As entity_type_id

        From (

            Select	sd.submission_id				        As submission_id,
                    sd.source_id					        As source_id,
                    sd.local_db_id				            As local_db_id,
                    sd.public_db_id				            As public_db_id,

                    ps.physical_sample_id                   As physical_sample_id,
                    ps.sample_name			                As sample_name,
                    sdt.type_name				            As type_name,
                    sd.description			                As description,

                    sd.date_updated				            As date_updated

            From clearing_house.view_sample_descriptions sd
            Join clearing_house.view_sample_description_types sdt
              On sdt.merged_db_id = sd.sample_description_type_id
             And sdt.submission_id In (0, sd.submission_id)
            Join clearing_house.view_physical_samples ps
              On ps.merged_db_id = sd.physical_sample_id
             And ps.submission_id In (0, sd.submission_id)

        ) As LDB

        Left Join (

            Select sd.sample_description_id                 As sample_description_id,
                   ps.physical_sample_id				    As physical_sample_id,
                   ps.sample_name				            As sample_name,
                   sdt.type_name					        As type_name,
                   sd.description				            As description
            From public.tbl_sample_descriptions sd
            Join public.tbl_sample_description_types sdt
              On sdt.sample_description_type_id = sd.sample_description_type_id
            Join public.tbl_physical_samples ps
              On ps.physical_sample_id = sd.physical_sample_id

        ) as RDB
          On RDB.sample_description_id = LDB.public_db_id

        Where LDB.source_id = 1
          And LDB.submission_id = $1

        Order by LDB.physical_sample_id;

End
$BODY$;

/*****************************************************************************************************************************
**	Function	fn_clearinghouse_report_sample_group_descriptions
**	Who			Roger Mähler
**	When		2018-03-29
**	What		Displays sample group descriptions
**	Uses
**	Used By
**	Revisions
******************************************************************************************************************************/

CREATE OR REPLACE FUNCTION clearing_house.fn_clearinghouse_report_sample_group_descriptions(integer)
RETURNS TABLE(
    local_db_id integer,
    physical_sample_id integer,
    sample_name character varying,
    type_name character varying,
    description character varying,
    public_db_id integer,
    public_physical_sample_id integer,
    public_sample_name character varying,
    public_type_name character varying,
    public_description character varying,
    date_updated text,
    entity_type_id integer
)
    LANGUAGE 'plpgsql'
AS $BODY$

Declare
    entity_type_id int;
Begin

    entity_type_id := clearing_house.fn_get_entity_type_for('tbl_sample_group_descriptions');

	Return Query

        Select
            LDB.local_db_id						            As local_db_id,
            LDB.sample_group_id					            As sample_group_id,
            LDB.sample_group_name							As sample_group_name,
            LDB.type_name								    As type_name,
            LDB.group_description						    As group_description,

            LDB.public_db_id						        As public_db_id,
            RDB.sample_group_id						        As public_sample_group_id,
            RDB.sample_group_name							As public_sample_group_name,
            RDB.type_name								    As public_type_name,
            RDB.group_description							As public_group_description,

            to_char(LDB.date_updated,'YYYY-MM-DD')			As date_updated,
            entity_type_id						            As entity_type_id

        From (

            Select	sd.submission_id				        As submission_id,
                    sd.source_id					        As source_id,
                    sd.local_db_id				            As local_db_id,
                    sd.public_db_id				            As public_db_id,

                    sg.sample_group_id                      As sample_group_id,
                    sg.sample_group_name			        As sample_group_name,
                    sdt.type_name				            As type_name,
                    sd.group_description			        As group_description,

                    sd.date_updated				            As date_updated

            From clearing_house.view_sample_group_descriptions sd
            Join clearing_house.view_sample_group_description_types sdt
              On sdt.merged_db_id = sd.sample_group_description_type_id
             And sdt.submission_id In (0, sd.submission_id)
            Join clearing_house.view_sample_groups sg
              On sg.merged_db_id = sd.sample_group_id
             And sg.submission_id In (0, sd.submission_id)

        ) As LDB

        Left Join (

       		Select  sgd.sample_group_description_id     As sample_group_description_id,
                    sg.sample_group_id					As sample_group_id,
					sg.sample_group_name 				As sample_group_name,
					sgdt.type_name						As type_name,
					sgd.group_description				As group_description

			From public.tbl_sample_groups sg
			Join public.tbl_sample_group_descriptions sgd
              On sgd.sample_group_id = sg.sample_group_id
            Join public.tbl_sample_group_description_types sgdt
              On sgdt.sample_group_description_type_id = sgd.sample_group_description_type_id

        ) As RDB
		  On RDB.sample_group_description_id = LDB.public_db_id

        Where LDB.source_id = 1
          And LDB.submission_id = $1

        Order by LDB.sample_group_id;

End
$BODY$;
call clearing_house.chown('clearing_house', 'clearinghouse_worker');
-- commit;
