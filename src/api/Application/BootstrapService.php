<?php

namespace Application {

    class BootstrapService {

        public $loader = null;
        public $config = null;
        public $registry = null;
        public $logger = null;
        public $locator = null;

        protected $submission_service = null;

        function __construct() {
            $options =
            $this->registry = new \Repository\RepositoryRegistry();
            $this->locator = new \Services\Locator();
        }

        public function getCurrentUserId() {
            // TODO Return logged in user instead...
            return 4;
        }

        public function getCurrentUser() {
            $user = $this->registry->getUserRepository()->findById($this->getCurrentUserId());
            $user["password"] = "";
            return $user;
        }

        public function getUsersModel() {
            $users = $this->registry->getUserRepository()->findAll();
            array_walk($users, function(&$x, $i) { $x["password"] = ""; } );
            return $users;
        }

        public function getUserRoleTypes() {
            $model = $this->registry->getUserRepository()->getUserRoleTypes();
            return $model;
        }

        public function getDataProviderGradeTypes() {
            $model = $this->registry->getUserRepository()->getDataProviderGradeTypes();
            return $model;
        }

        public function getRejectTypes() {
            $model = $this->registry->getSubmissionRejectRepository()->getRejectTypes();
            return $model;
        }

        function getReports()
        {
            $model =  $this->registry->getReportRepository()->findAll();
            return $model;
        }

        function getSecurityModel()
        {
            $model = $this->locator->getSecurityService()->getSecurityModel();
            return $model;
        }

        function getLatestUpdatedSites()
        {
            $model = $this->registry->getSiteRepository()->getLatestUpdatedSites();
            return $model;
        }

        function getInfoReferences()
        {
            $model = $this->registry->getSettingRepository()->getInfoReferences();
            return $model;
        }

        function getDataSetListKeys()
        {
            $model = $this->registry->getDataSetRepository()->dataset_model_elements;
            return $model;
        }
    }
}
?>
