<?php

namespace Repository {

    class RepositoryRegistry {

        private $con = null;
        protected $schema_name = null;
        protected $options = null;
        protected $store = array();

        public function getConnection()
        {
            return $this->con ?: ($this->con = \InfraStructure\ConnectionFactory::Create($this->options));
        }

        function __construct($schema_name = "clearing_house") {
            $options = \InfraStructure\ConfigService::readDatabaseConfigFromEnvironment();
            if (!$options) {
                $options = \InfraStructure\ConfigService::readDatabaseConfigFromFile();
            }
            $this->options = $options;
            $this->schema_name = $schema_name;
        }

        public function getRepository($class_name)
        {
            if (!array_key_exists($class_name, $this->store)) {
                $connection = $this->getConnection();
                $this->store[$class_name] = new $class_name($connection, $this->schema_name);
            }
            return $this->store[$class_name];
        }

        public function getUserRepository()
        {
            return $this->getRepository("\Repository\UserRepository");
        }

        public function getSubmissionRepository()
        {
            return $this->getRepository("\Repository\SubmissionRepository");
        }

        public function getSiteRepository()
        {
            return $this->getRepository("\Repository\SiteRepository");
        }

        public function getReportRepository()
        {
            return $this->getRepository("\Repository\ReportRepository");
        }

        public function getSampleGroupRepository()
        {
            return $this->getRepository("\Repository\SampleGroupRepository");
        }

        public function getSampleRepository()
        {
            return $this->getRepository("\Repository\SampleRepository");
        }

        public function getSubmissionRejectRepository()
        {
            return $this->getRepository("\Repository\SubmissionRejectRepository");
        }

        public function getSessionRepository()
        {
            return $this->getRepository("\Repository\SessionRepository");
        }

        public function getActivityRepository()
        {
            return $this->getRepository("\Repository\ActivityRepository");
        }

        public function getDataSetRepository()
        {
            return $this->getRepository("\Repository\DataSetRepository");
        }

        public function getAcceptedQueueRepository()
        {
            return $this->getRepository("\Repository\AcceptedQueueRepository");
        }

        public function getSignalRepository()
        {
            return $this->getRepository("\Repository\SignalRepository");
        }

        public function getSettingRepository()
        {
            return $this->getRepository("\Repository\SettingRepository");
        }
    }

}
?>
