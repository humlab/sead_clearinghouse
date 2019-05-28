
-- CREATE DATABASE sead_dev_clearinghouse WITH TEMPLATE sead_staging OWNER sead_master;

CREATE SCHEMA IF NOT EXISTS clearing_house_commit;

/*********************************************************************************************************************************
**  Function    fn_dba_sead_entity_tables
**  When
**  What
**  Who         Roger Mähler
**  Used By
**  Revisions
**********************************************************************************************************************************/
-- Select * From  clearing_house.fn_dba_sead_entity_tables();
CREATE OR REPLACE FUNCTION clearing_house.fn_dba_sead_entity_tables()
RETURNS void LANGUAGE 'plpgsql' AS $BODY$
Begin

    Drop Table If Exists clearing_house.tbl_clearinghouse_entity_tables;

    Create Table If Not Exists clearing_house.tbl_clearinghouse_entity_tables (
        table_schema information_schema.sql_identifier not null,
        table_name information_schema.sql_identifier PRIMARY KEY,
        pk_name information_schema.sql_identifier not null,
        entity_name information_schema.sql_identifier not null,
        is_global_lookup information_schema.yes_or_no not null default('NO'),
        is_local_lookup information_schema.yes_or_no not null default('NO'),
		is_aggregate_root information_schema.yes_or_no not null default('NO'),
		parent_aggregate information_schema.sql_identifier null
    );

    Drop Index If Exists clearing_house.idx_clearinghouse_entity_tables1;

    Create Unique Index idx_clearinghouse_entity_tables1 On clearing_house.tbl_clearinghouse_entity_tables (entity_name);

	Delete From clearing_house.tbl_clearinghouse_entity_tables;

	--, is_lookup, is_aggregate_root, aggregate_root
	Insert Into clearing_house.tbl_clearinghouse_entity_tables (table_schema, table_name, pk_name, entity_name)
		Select x.table_schema, x.table_name, x.column_name,  clearing_house.fn_sead_table_entity_name(x.table_name::text)
		From clearing_house.fn_dba_get_sead_public_db_schema() x
		Left Join clearing_house.tbl_clearinghouse_entity_tables y
		  On y.table_name = x.table_name
		 And y.pk_name = x.column_name
		Where x.is_pk = 'YES'
		  And y.table_name Is NULL
		Order By 2, 3;
End
$BODY$;

ALTER FUNCTION clearing_house.fn_dba_sead_entity_tables()
    OWNER TO clearinghouse_worker;

Select clearing_house.fn_dba_sead_entity_tables();

UPDATE clearing_house.tbl_clearinghouse_entity_tables
    SET is_global_lookup = 'YES'
WHERE table_name IN (
    'tbl_activity_types',
    'tbl_age_types',
    'tbl_aggregate_order_types',
    'tbl_abundance_elements',
    'tbl_modification_types',
    'tbl_ceramics_lookup',
    'tbl_chron_control_types',
    'tbl_dendro_lookup',
    'tbl_tephras',
    'tbl_colours',
    'tbl_contacts',
    'tbl_contact_types',
    'tbl_data_types',
    'tbl_data_type_groups',
    'tbl_dataset_masters',
    'tbl_dataset_submission_types',
    'tbl_dating_labs',
    'tbl_dating_uncertainty',
    'tbl_dimensions',
    'tbl_ecocodes',
    'tbl_ecocode_definitions',
    'tbl_ecocode_groups',
    'tbl_error_uncertainties',
    'tbl_feature_types',
    'tbl_identification_levels',
    'tbl_image_types',
    'tbl_languages',
    'tbl_locations',
    'tbl_location_types',
    'tbl_relative_ages',
    'tbl_relative_age_refs',
    'tbl_relative_age_types',
    'tbl_method_groups',
    'tbl_methods',
    'tbl_project_stages',
    'tbl_project_types',
    'tbl_rdb',
    'tbl_rdb_codes',
    'tbl_rdb_systems',
    'tbl_record_types',
    'tbl_alt_ref_types',
    'tbl_biblio',
    'tbl_sample_description_types',
    'tbl_sample_description_sample_group_contexts',
    'tbl_sample_location_type_sampling_contexts',
    'tbl_sample_types',
    'tbl_sample_group_description_types',
    'tbl_sample_group_description_type_sampling_contexts',
    'tbl_sample_group_sampling_contexts',
    'tbl_sample_location_types',
    'tbl_seasons',
    'tbl_season_or_qualifier',
    'tbl_season_types',
    'tbl_taxa_tree_master',
    'tbl_taxa_common_names',
    'tbl_taxa_images',
    'tbl_taxa_measured_attributes',
    'tbl_taxa_reference_specimens',
    'tbl_taxa_seasonality',
    'tbl_species_associations',
    'tbl_species_association_types',
    'tbl_taxa_synonyms',
    'tbl_taxonomic_order',
    'tbl_taxonomic_order_biblio',
    'tbl_taxonomic_order_systems',
    'tbl_taxonomy_notes',
    'tbl_text_biology',
    'tbl_text_distribution',
    'tbl_text_identification_keys',
    'tbl_taxa_tree_authors',
    'tbl_taxa_tree_families',
    'tbl_taxa_tree_genera',
    'tbl_taxa_tree_orders',
    'tbl_units',
    'tbl_years_types'
);

UPDATE clearing_house.tbl_clearinghouse_entity_tables
    SET is_local_lookup = 'YES'
WHERE table_name IN (
    'tbl_coordinate_method_dimensions',
    'tbl_aggregate_datasets',
    'tbl_features',
    'tbl_horizons',
    'tbl_chronologies',
    'tbl_projects'
 );

UPDATE clearing_house.tbl_clearinghouse_entity_tables
    SET is_local_lookup = 'YES'
WHERE table_name IN (
    'tbl_coordinate_method_dimensions',
    'tbl_aggregate_datasets',
    'tbl_features',
    'tbl_horizons',
    'tbl_chronologies',
    'tbl_projects'
);

UPDATE clearing_house.tbl_clearinghouse_entity_tables
    SET is_aggregate_root = 'YES'
WHERE entity_name IN (
    'site',
    'sample_group',
    'physical_sample',
    'analysis_entity',
    'dataset',
    'tbl_chronologies',
    'tbl_projects'
);

with entity_relations as (
    Select p.table_name as parent_table_name, p.entity_name as parent_entity_name, p.is_aggregate_root, c.table_name, c.entity_name, r.column_name
    From clearing_house.fn_dba_get_sead_public_db_schema('public') r
    Join clearing_house.tbl_clearinghouse_entity_tables c
      On c.table_name = r.table_name
    Join clearing_house.tbl_clearinghouse_entity_tables p
      On p.table_name = r.fk_table_name
    Where r.is_fk = 'YES'
      And 'YES' Not In (p.is_global_lookup) --, p.is_local_lookup, p.is_aggregate_root)
)
    SELECT table_name, entity_name, parent_table_name, parent_entity_name, is_aggregate_root
    FROM entity_relations
    ORDER BY 2, 4

With table_columns As (
    Select table_name, string_agg('x.' || column_name, ', ' Order By ordinal_position asc) as columns
    From clearing_house.fn_dba_get_sead_public_db_schema() t
    Group By table_name
) Select tc.table_name, t.entity_name, tc.columns
  From table_columns tc
  Join clearing_house.tbl_clearinghouse_entity_tables t
    On t.table_name = tc.table_name

    Select *
    From clearing_house.fn_dba_get_sead_public_db_schema('public') r