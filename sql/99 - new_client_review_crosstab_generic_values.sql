-- Generic crosstab report (replaces cermaics crosstab also)

Create Or Replace View clearing_house.view_generic_analysis_lookup_values As
    Select 1 As analysis_type_id, d.submission_id, d.source_id, d.merged_db_id, d.local_db_id, d.public_db_id, d.analysis_entity_id, d.measurement_value, d.date_updated, d.dendro_lookup_id As lookup_id, dl.name As lookup
    From clearing_house.view_dendro d
    Left Join clearing_house.view_dendro_lookup dl
      On dl.submission_id = d.submission_id
     And dl.merged_db_id = d.dendro_lookup_id
    Union
    Select 2 As analysis_type_id, c.submission_id, c.source_id, c.merged_db_id, c.local_db_id, c.public_db_id, c.analysis_entity_id, c.measurement_value, c.date_updated, c.ceramics_lookup_id As lookup_id, cl.name As lookup
    From clearing_house.view_ceramics c
    Left join clearing_house.view_ceramics_lookup cl
      On cl.submission_id = c.submission_id
     And cl.merged_db_id = c.ceramics_lookup_id;

Create Or Replace View clearing_house.public_view_generic_analysis_lookup_values As
    Select 1 As analysis_type_id, 0 AS submission_id, 2 AS source_id, d.dendro_id AS merged_db_id, 0 AS local_db_id, d.dendro_id AS public_db_id, d.analysis_entity_id, d.measurement_value, d.date_updated, d.dendro_lookup_id AS lookup_id, dl.name AS lookup
    From public.tbl_dendro d
    Left join public.tbl_dendro_lookup dl
      On d.dendro_lookup_id = dl.dendro_lookup_id
    Union
    Select 2 As analysis_type_id, 0 AS submission_id, 2 AS source_id, c.ceramics_id AS merged_db_id, 0 AS local_db_id, c.ceramics_id AS public_db_id, c.analysis_entity_id AS analysis_entity_id, c.measurement_value AS measurement_value, c.date_updated AS date_updated, c.ceramics_lookup_id AS lookup_id, cl.name AS lookup
    From public.tbl_ceramics c
    Left join public.tbl_ceramics_lookup cl
      On c.ceramics_lookup_id = cl.ceramics_lookup_id;

Create Or Replace View clearing_house.view_generic_analysis_lookup As
    Select distinct 1 As analysis_type_id, name
    From clearing_house.tbl_ceramics_lookup
    Union
    Select distinct 2 As analysis_type_id, name
    From clearing_house.tbl_dendro_lookup;

Create Or Replace Function clearing_house.fn_clearinghouse_review_dataset_generic_analysis_lookup_values(p_submission_id IN integer, p_dataset_id IN integer)
Returns Table (
    local_db_id integer,
    method_id integer,
    dataset_name character varying,
    sample_name character varying,
    method_name character varying,
    lookup_name character varying,
    measurement_value character varying,
    public_db_id integer,
    public_method_id integer,
    public_sample_name character varying,
    public_method_name character varying,
    public_lookup_name character varying,
    public_measurement_value character varying,
    entity_type_id integer,
    date_updated character varying
) AS
$BODY$
Declare
    entity_type_id int;
Begin
    entity_type_id := clearing_house.fn_get_entity_type_for('tbl_ceramics');
	Return Query
        With LDB As (
            Select	d.submission_id                 As submission_id,
                    d.source_id                     As source_id,
                    d.local_db_id 			        As local_dataset_id,
                    d.dataset_name 			        As local_dataset_name,
                    ps.local_db_id 			        As local_physical_sample_id,
                    m.local_db_id 			        As local_method_id,

                    d.public_db_id 			        As public_dataset_id,
                    ps.public_db_id 			    As public_physical_sample_id,
                    m.public_db_id 			        As public_method_id,

                    vv.analysis_entity_id,
                    vv.local_db_id					As local_db_id,
                    vv.public_db_id					As public_db_id,

                    ps.sample_name					As sample_name,
                    m.method_name					As method_name,
                    vv.lookup					    As lookup_name,
                    vv.measurement_value			As measurement_value,

                    vv.date_updated                 As date_updated

            From clearing_house.view_datasets d
            Join clearing_house.view_analysis_entities ae
              On ae.dataset_id = d.merged_db_id
             And ae.submission_id In (0, d.submission_id)
            Join clearing_house.view_generic_analysis_lookup_values vv
              On vv.analysis_entity_id = ae.merged_db_id
             And vv.submission_id In (0, d.submission_id)
            Join clearing_house.view_physical_samples ps
              On ps.merged_db_id = ae.physical_sample_id
             And ps.submission_id In (0, d.submission_id)
            Join clearing_house.view_methods m
              On m.merged_db_id = d.method_id
             And m.submission_id In (0, d.submission_id)
           Where 1 = 1
              And d.submission_id = p_submission_id -- perf
              And d.local_db_id = Coalesce(-p_dataset_id, d.local_db_id) -- perf
        ), RDB As (
            Select	d.dataset_id 			    As dataset_id,
                    ps.physical_sample_id       As physical_sample_id,
                    m.method_id                 As method_id,

                    pvv.public_db_id            As public_db_id,
                    pvv.analysis_entity_id,
                    ps.sample_name              As sample_name,
                    m.method_name               As method_name,

                    lv.lookup                   As lookup_name,
                    lv.measurement_value        As measurement_value,
                    lv.date_updated			    As date_updated

                    From public.tbl_datasets d
                    Join public.tbl_analysis_entities ae
                      On ae.dataset_id = d.dataset_id
                    Join clearing_house.public_view_generic_analysis_lookup_values lv
                      On lv.analysis_entity_id = ae.analysis_entity_id
                    Join public.tbl_physical_samples ps
                      On ps.physical_sample_id = ae.physical_sample_id
                    Join public.tbl_methods m
                      On m.method_id = d.method_id
                )
            Select

                LDB.local_db_id                         As local_db_id,
                LDB.local_method_id 			        As method_id,

                LDB.local_dataset_name					As dataset_name,
                LDB.sample_name							As sample_name,
                LDB.method_name							As method_name,
                LDB.lookup_name							As lookup_name,
                LDB.measurement_value					As measurement_value,

                LDB.public_db_id 			            As public_db_id,
                LDB.public_method_id 			        As public_method_id,

                RDB.sample_name							As public_sample_name,
                RDB.method_name							As public_method_name,
                RDB.lookup_name							As public_lookup_name,
                RDB.measurement_value					As public_measurement_value,

                entity_type_id							As entity_type_id,
                to_char(LDB.date_updated,'YYYY-MM-DD')	As date_updated

            From LDB
            Left Join RDB
              On 1 = 1
             And RDB.analysis_entity_id = LDB.analysis_entity_id
            Where LDB.source_id = 1
              And LDB.submission_id = p_submission_id
              And LDB.local_dataset_id = Coalesce(-p_dataset_id, LDB.local_dataset_id);
            -- Order by LDB.local_physical_sample_id;

End $BODY$ LANGUAGE plpgsql VOLATILE;

-- Select * from clearing_house.fn_clearinghouse_review_generic_analysis_lookup_values_crosstab(3,0);
Create Or Replace Function clearing_house.fn_clearinghouse_review_generic_analysis_lookup_values_crosstab(p_submission_id int, p_analysis_type_id int)
Returns Table (
    sample_name text,
    local_db_id int,
    public_db_id int,
    entity_type_id int,
    json_data_values json
)
As $$
Declare
	v_category_sql text;
	v_source_sql text;
	v_typed_fields text;
	v_column_names text;
	v_sql text;
Begin

    If coalesce(p_analysis_type_id, 0) = 0 Then
        Select analysis_type_id
            Into p_analysis_type_id
        From clearing_house.view_generic_analysis_lookup_values
        Where submission_id = p_submission_id
        limit 1;
    End If;

	v_category_sql = format('
        SELECT name
        FROM clearing_house.view_generic_analysis_lookup
        WHERE analysis_type_id = %s
        ORDER BY name', p_analysis_type_id);

	v_source_sql = format('
		SELECT	sample_name,                                            -- row_name
                local_db_id, public_db_id, entity_type_id,              -- extra_columns
				lookup_name,                                            -- category
				ARRAY[lookup_name, ''text'', max(measurement_value), max(public_measurement_value)] as measurement_value
		FROM clearing_house.fn_clearinghouse_review_dataset_generic_analysis_lookup_values(%s, null) c
		WHERE TRUE
          AND %s in (0, analysis_type_id)
		GROUP BY sample_name, local_db_id, public_db_id, entity_type_id, lookup_name
		ORDER BY sample_name, lookup_name', p_submission_id, coalesce(p_analysis_type_id, 0));

	Select string_agg(format('%I text[]', name), ', ' order by name) as typed_fields,
		   string_agg(format('ARRAY[%L, ''local'', ''public'']', name), ', ' order by name) AS column_names
	    Into v_typed_fields, v_column_names
	From clearing_house.view_generic_analysis_lookup
    Where analysis_type_id = p_analysis_type_id;

    IF v_column_names IS NULL THEN

        Return Query
            Select *
            From (VALUES ('NADA'::text, null::int, null::int, null::int, null::json)) AS V
            Where FALSE;

    Else

        Select format('
            SELECT sample_name, local_db_id, public_db_id, entity_type_id, array_to_json(ARRAY[%s]) AS json_data_values
            FROM crosstab(%L, %L) AS ct(sample_name text, local_db_id int, public_db_id int, entity_type_id int, %s)',
                      v_column_names, v_source_sql, v_category_sql, v_typed_fields)
        Into v_sql;

        Raise Info E'%s\n%s\n%s', v_sql, v_category_sql, v_source_sql;

        Return Query Execute v_sql;

    End IF;
End
$$ LANGUAGE 'plpgsql';




