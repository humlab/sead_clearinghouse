<?php

namespace Repository {

    class UserRepository extends RepositoryBase {

        function __construct(&$conn, $schema_name) {
            parent::__construct($conn, "tbl_clearinghouse_users", array("user_id"), $schema_name, "user_id");
        }

        public function getUserRoleTypes() {
            return $this->getAdapter()->fetch_table("clearing_house.tbl_clearinghouse_user_roles");
        }

        public function getDataProviderGradeTypes() {
            return $this->getAdapter()->fetch_table("clearing_house.tbl_clearinghouse_data_provider_grades");
        }

        public function findByUsername($username)
        {
            $values = $this->find(array("user_name" => $username));
            if (count($values) > 0)
                return $values[0];
            return null;
        }

        public static function create_new()
        {
            return array(
                "user_id" => 0,
                "user_name" => "",
                "password" => "",
                "email" => "",
                "signal_receiver" => false,
                "role_id" => 0,
                "data_provider_grade_id" => 0,
                "create_date" => date("Y-m-d H:i:s"), // now(),
                "full_name" => ""
            );
        }
    }

}

?>