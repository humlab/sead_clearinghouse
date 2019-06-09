<?php

namespace Repository {

    class SampleRepository extends RepositoryBase {

        function __construct(&$conn, $schema_name) {
            parent::__construct($conn, "tbl_physical_samples", array("submission_id", "physical_sample_id"), $schema_name);
        }


        function getSampleModel($submission_id, $sample_id)
        {

            $sample = $this->getAdapter()->execute_procedure("clearing_house.fn_clearinghouse_review_sample", array($submission_id, $sample_id), \InfraStructure\DatabaseConnection::Execute_GetFirst);
            $alternative_names = $this->getAdapter()->execute_procedure("clearing_house.fn_clearinghouse_review_sample_alternative_names", array($submission_id, $sample_id));
            $features = $this->getAdapter()->execute_procedure("clearing_house.fn_clearinghouse_review_sample_features", array($submission_id, $sample_id));
            $notes = $this->getAdapter()->execute_procedure("clearing_house.fn_clearinghouse_review_sample_notes", array($submission_id, $sample_id));
            $dimensions = $this->getAdapter()->execute_procedure("clearing_house.fn_clearinghouse_review_sample_dimensions", array($submission_id, $sample_id));
            $descriptions = $this->getAdapter()->execute_procedure("clearing_house.fn_clearinghouse_review_sample_descriptions", array($submission_id, $sample_id));
            $horizons = $this->getAdapter()->execute_procedure("clearing_house.fn_clearinghouse_review_sample_horizons", array($submission_id, $sample_id));
            $colours = $this->getAdapter()->execute_procedure("clearing_house.fn_clearinghouse_review_sample_colours", array($submission_id, $sample_id));
            $images = $this->getAdapter()->execute_procedure("clearing_house.fn_clearinghouse_review_sample_images", array($submission_id, $sample_id));
            $locations = $this->getAdapter()->execute_procedure("clearing_house.fn_clearinghouse_review_sample_locations", array($submission_id, $sample_id));
            $dendro_dates = $this->getAdapter()->execute_procedure("clearing_house.fn_clearinghouse_review_sample_dendro_dates", array($submission_id, $sample_id));
            $dendro_date_notes = $this->getAdapter()->execute_procedure("clearing_house.fn_clearinghouse_review_sample_dendro_date_notes", array($submission_id, $sample_id));
            $positions = $this->getAdapter()->execute_procedure("clearing_house.fn_clearinghouse_review_sample_positions", array($submission_id, $sample_id));

            return array(

                "local_db_id" => $this->getKeyValueIfExistsOrDefault($sample, "local_db_id", 0),
                "entity_type_id" => $this->getKeyValueIfExistsOrDefault($sample, "entity_type_id", 0),

                "sample" => $sample,

                "alternative_names" => $alternative_names,
                "features" => $features,
                "notes" => $notes,
                "dimensions" => $dimensions,
                "descriptions" => $descriptions,
                "horizons" => $horizons,
                "colours" => $colours,
                "images" => $images,
                "locations" => $locations,
                "positions" => $positions,
                "dendro_dates" => $dendro_dates,
                "dendro_date_notes" => $dendro_date_notes

            );

        }

        function NotImplemented()
        {
            return array();
        }

    }


}

?>