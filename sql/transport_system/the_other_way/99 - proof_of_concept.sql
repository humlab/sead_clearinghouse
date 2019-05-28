-- CREATE DATABASE sead_dev_clearinghouse WITH TEMPLATE sead_staging OWNER sead_master;
CREATE SCHEMA IF NOT EXISTS clearing_house_commit;

-- Drop Function If Exists clearing_house.fn_sead_entity_tables();
-- Select * From clearing_house.fn_sead_entity_tables();

CREATE TABLE IF NOT EXISTS clearing_house_commit.sead_entity_tables (
    table_name information_schema.sql_identifier PRIMARY KEY,
    root_table_name information_schema.sql_identifier NULL,
    entity_name information_schema.sql_identifier,
	is_lookup boolean,
)

Select distinct clearing_house_commit.fn_sead_table_entity_name(child_table, parent_table, child_column, parent_column
From clearing_house_commit.sead_entity_tables t
Left clearing_house.fn_dba_get_fk_constraints('public') r
  On r.child_table = t.table_name;

SELECT *
FROM clearing_house.tbl_sites s



/*****************************************************************************************************************************
**	Function	transport_site
**	Who			Roger Mähler
**	When		2018-06-18
**	What
**  Note
    1. Set or get entity's public SEAD ID

**  Uses
**  Used By
**	Revisions
******************************************************************************************************************************/

DROP FUNCTION IF EXISTS clearing_house_commit.transport_site();

-- REFRESH MATERIALIZED VIEW  clearing_house.view_local_to_public_id;

CREATE OR REPLACE FUNCTION clearing_house_commit.transport_site() RETURNS TRIGGER AS $$
	DECLARE
		v_public_id int;
		v_entity public.tbl_sites;
    BEGIN

		IF TG_OP <> 'INSERT' THEN
			RAISE EXCEPTION 'TG_OP % unexpected. INSERT is only supported TG_OP!', TG_OP
		END IF;

		/************************************************************************************************************
		** Set public SEAD id
		*************************************************************************************************************/

		v_public_id = CASE
			WHEN NEW.public_db_id > 0 THEN NEW.public_db_id
			ELSE nextval(pg_get_serial_sequence('public.tbl_sites', 'site_id'))
		END;

		/************************************************************************************************************
		** Assign aggregate root
		*************************************************************************************************************/

		v_entity = NEW;

		v_entity.site_id = v_public_id;
		v_entity.altitude = NEW.altitude
		v_entity.date_updated = NEW.date_updated
		v_entity.latitude_dd = NEW.latitude_dd
		v_entity.longitude_dd = NEW.longitude_dd
		v_entity.national_site_identifier = NEW.national_site_identifier
		v_entity.site_description = NEW.site_description
		v_entity.site_location_accuracy = NEW.site_location_accuracy
		v_entity.site_name = NEW.site_name

		/************************************************************************************************************
		** Translate FK references
		*************************************************************************************************************/

		-- v_entity.site_preservation_status_id = clearing_house.fn_local_to_public_id(NEW.submission_id, 'tbl_site_preservation_status_id', NEW.site_preservation_status_id);

		-- INSERT AGGREGATE ROOT
		/************************************************************************************************************
		** Insert aggregate root
		*************************************************************************************************************/

		INSERT INTO public.tbl_sites
			SELECT *
			FROM

		INSERT INTO public.tbl_sites VALUES (v_entity.*);
			/* ON CONFLICT UPDATE; -- NOTE! PostgreSQL >= 9.5 NEEDED: */

		/************************************************************************************************************
		** Update public_db_id
		*************************************************************************************************************/

		IF NEW.public_db_id = 0 THEN
			UPDATE clearing_house.tbl_sites
				SET public_db_id = v_public_id
			WHERE submission_id = NEW.submission_id
			  AND local_db_id = NEW.local_db_id;
		END;

		/************************************************************************************************************
		** Insert aggregate components
		*************************************************************************************************************/

		INSERT INTO clearing_house_commit.site_location_gateway
			SELECT *
			FROM clearing_house.tbl_site_locations
			WHERE submission_id = NEW.submission_id
			  AND site_id = NEW.local_db_id;

		INSERT INTO clearing_house_commit.site_image_gateway
			SELECT *
			FROM clearing_house.tbl_site_images
			WHERE submission_id = NEW.submission_id
			  AND site_id = NEW.local_db_id;

		INSERT INTO clearing_house_commit.site_natgridref_gateway
			SELECT *
			FROM clearing_house.site_natgridrefs
			WHERE submission_id = NEW.submission_id
			  AND site_id = NEW.local_db_id;

		INSERT INTO clearing_house_commit.other_record_gateway
			SELECT *
			FROM clearing_house.tbl_site_other_records
			WHERE submission_id = NEW.submission_id
			  AND site_id = NEW.local_db_id;

		INSERT INTO clearing_house_commit.site_preservation_status_gateway
			SELECT *
			FROM clearing_house.public.tbl_site_preservation_status
			WHERE submission_id = NEW.submission_id
			  AND site_id = NEW.local_db_id;

		RETURN NULL;
    END;
$$ LANGUAGE plpgsql;

/************************************************************************************************************
** Assign gateway triggers
*************************************************************************************************************/

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

-- -- Select *
-- -- From (
-- -- 	Select pg_get_serial_sequence(table_name, column_name) As sequence_name
-- -- 	From clearing_house.fn_dba_get_sead_public_db_schema('public')
-- -- ) s
-- -- Where Not s.sequence_name Is NULL
-- -- limit 1
