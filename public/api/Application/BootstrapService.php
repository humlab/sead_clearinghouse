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
            return json_encode($user);
        }
        
        public function getUsersModel() {
            $users = $this->registry->getUserRepository()->findAll();
            array_walk($users, function(&$x, $i) { $x["password"] = ""; } );
            return json_encode($users);
        }

        public function getUserRoleTypes() {
            $model = $this->registry->getUserRepository()->getUserRoleTypes();
            return json_encode($model);
        }

        public function getDataProviderGradeTypes() {
            $model = $this->registry->getUserRepository()->getDataProviderGradeTypes();
            return json_encode($model);
        }
        
        public function getRejectTypes() {
            $model = $this->registry->getSubmissionRejectRepository()->getRejectTypes();
            return json_encode($model);
        }
        
        function getReports()
        {
            $model =  $this->registry->getReportRepository()->findAll();
            return json_encode($model);
        }
        
        function getSecurityModel()
        {
            $model = $this->locator->getSecurityService()->getSecurityModel();
            return json_encode($model, JSON_FORCE_OBJECT);
        }
        
        function getLatestUpdatedSites()
        {
            $model = $this->registry->getSiteRepository()->getLatestUpdatedSites();
            return json_encode($model);
        }
        
        function getInfoReferences()
        {
            $model = $this->registry->getSettingRepository()->getInfoReferences();
            return json_encode($model);
        }
    }
}
?>
