
Select v.submission_id, 1 as source_id, -v.local_db_id, values[1]::date AS date_updated, values[2]::float::integer AS cloned_id, values[3]::text AS url, values[4]::text AS phone_number, values[5]::text AS last_name, values[6]::text AS first_name, values[7]::text AS email, values[8]::float::integer AS location_id, values[9]::text AS address_2, values[10]::text AS address_1, values[11]::float::integer AS contact_id
From clearing_house.fn_get_extracted_values_as_arrays(4, 'tbl_contacts') as v(submission_id, table_name, local_db_id, public_db_id, values)



SELECT *
FROM clearing_house.fn_select_xml_content_values(4, 'TblContacts')
  
/*
Delete From clearing_house.tbl_clearinghouse_submission_xml_content_values Where submission_id = 4;
Delete From clearing_house.tbl_clearinghouse_submission_xml_content_columns Where submission_id = 4;
Delete From clearing_house.tbl_clearinghouse_submission_xml_content_records Where submission_id = 4;
Delete From clearing_house.tbl_clearinghouse_submission_xml_content_tables  Where submission_id = 4;
        
Select clearing_house.fn_extract_and_store_submission_tables(4);
Analyze clearing_house.tbl_clearinghouse_submission_xml_content_tables;
Select clearing_house.fn_extract_and_store_submission_columns(4);
Analyze clearing_house.tbl_clearinghouse_submission_xml_content_columns;
Select clearing_house.fn_extract_and_store_submission_records(4);
Analyze  clearing_house.tbl_clearinghouse_submission_xml_content_records;
Select clearing_house.fn_extract_and_store_submission_values(4);
Analyze clearing_house.tbl_clearinghouse_submission_xml_content_values;
*/



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