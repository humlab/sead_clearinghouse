<?php

namespace Repository {

    class SiteRepository extends RepositoryBase {

        function __construct(&$conn, $schema_name) {
            parent::__construct($conn, "tbl_sites", array("submission_id", "site_id"), $schema_name);
        }


        function findBySubmissionId($submission_id)
        {
            return $this->find( array("submission_id" => $submission_id) );
        }

        function getSiteModel($submission_id, $site_id)
        {

            $site = $this->getAdapter()->execute_procedure("clearing_house.fn_clearinghouse_review_site_client_data", array($submission_id, $site_id), \InfraStructure\DatabaseConnection::Execute_GetFirst);
            $locations = $this->getAdapter()->execute_procedure("clearing_house.fn_clearinghouse_review_site_locations_client_data", array($submission_id, $site_id));
            $references = $this->getAdapter()->execute_procedure("clearing_house.fn_clearinghouse_review_site_references_client_data", array($submission_id, $site_id));
            $natgridrefs = $this->getAdapter()->execute_procedure("clearing_house.fn_clearinghouse_review_site_natgridrefs_client_data", array($submission_id, $site_id));
            $projects = $this->getAdapter()->execute_procedure("clearing_house.fn_clearinghouse_review_projects_client_data", array($submission_id, $site_id));
            $images = $this->notImplemented();

            return array(
                "local_db_id" => $this->getKeyValueIfExistsOrDefault($site, "local_db_id", 0),
                "entity_type_id" => $this->getKeyValueIfExistsOrDefault($site, "entity_type_id", 0),
                "site" => $site,
                "locations" => $locations,
                "references" => $references,
                "natgridrefs" => $natgridrefs,
                "projects" => $projects,
                "images" => $images,
            );

        }

        function getLatestUpdatedSites()
        {
            return $this->getAdapter()->execute_procedure("clearing_house.fn_clearinghouse_latest_accepted_sites", array());
        }

        function notImplemented()
        {
            return array();
        }

    }



}

?>