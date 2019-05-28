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

		/************************************************************************************************************
		** Insert aggregate root
		*************************************************************************************************************/

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