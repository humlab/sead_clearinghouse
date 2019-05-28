/*****************************************************************************************************************************
**	Function	fn_create_gateway_views
**	Who			Roger Mähler
**	When		2018-06-18
**	What		Creates gateway views and triggers for CH data submit
**  Note        A skeleton trigger function is created
**  Uses
**  Used By
**	Revisions
******************************************************************************************************************************/
-- Select clearing_house_commit.fn_create_gateway_views()
-- Drop Function clearing_house.fn_create_gateway_views();
Create Or Replace Function clearing_house_commit.fn_setup_gateway_views(p_dry_run boolean=TRUE)
Returns void As $$
	Declare v_tablename text;
	Declare v_entity_name text;
	Declare sql_script text;
Begin
	For v_tablename, v_entity_name In (
		Select r.table_name, r.entity_name
		From clearing_house.fn_sead_entity_tables()
	)
	Loop
		sql_script = format(E'

			DROP VIEW IF EXISTS clearing_house_commit.%I_gateway CASCADE;

			CREATE OR REPLACE VIEW clearing_house_commit.%I_gateway AS
				SELECT *
				FROM clearing_house.%I
				WHERE FALSE;\n

            CREATE OR REPLACE FUNCTION clearing_house_commit.transport_%I() RETURNS TRIGGER AS $$
                DECLARE
                    v_public_db_id int;
                    v_public_db_entity public.%I;
                BEGIN

                    v_public_db_id = CASE
                        WHEN NEW.public_db_id > 0 THEN NEW.public_db_id
                        ELSE nextval(pg_get_serial_sequence(''public.%I'', ''site_id''))
                    END;

                    RETURN NULL;

                END;
            $$ LANGUAGE plpgsql;

			DROP TRIGGER IF EXISTS trigger_transport_%I ON clearing_house_commit.%I_gateway;

			CREATE TRIGGER trigger_transport_%I
				INSTEAD OF INSERT OR UPDATE OR DELETE ON clearing_house_commit.%I_gateway
					FOR EACH ROW EXECUTE PROCEDURE clearing_house_commit.transport_%I();\n',
							v_entity_name,
                            v_entity_name, v_tablename,
							v_entity_name, v_tablename, v_tablename,
                            v_entity_name, v_entity_name,
                            v_entity_name, v_entity_name, v_entity_name);

		If (p_dry_run) Then
			Raise Info '%', sql_script;
		Else
			Execute sql_script;
		End If;
	End Loop;
End $$ Language plpgsql;
