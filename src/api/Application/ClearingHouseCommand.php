<?php

namespace Application {

    class ClearingHouseCommand extends \Services\ServiceBase
    {

        public static function assertLoad()
        {
        }

        protected $use_case_id;
        protected $entity_type_id;

        function __construct($use_case_id = \Services\ActivityService::UseCase_Generic) {
            parent::__construct();
            $this->use_case_id = $use_case_id;
            $this->entity_type_id = \Repository\ActivityRepository::Generic_Entity_Type;
        }

        public function execute($entity_id, $payload = null)
        {
            $activity = $this->registerStart($entity_id);
            try {
                $result = $this->executeCommand($entity_id, $payload);
                $this->registerStop($activity);
            } catch (Exception $ex) {
                $this->registerStop($activity, \Services\ActivityService::Activity_State_Error, $ex->getMessage());
                throw $ex;
            }
            return $result;
        }

        public function executeCommand($entity_id, $payload)
        {
        }

        public function registerStart($entity_id)
        {
            return $this->locator->getActivityService()->startActivity(
                $this->use_case_id, $entity_id, null, $this->entity_type_id
            );
        }

        public function registerStop(&$activity)
        {
            $this->locator->getActivityService()->stopActivity($activity);
        }

        public function registerError(&$activity, $ex)
        {
            $this->locator->getActivityService()->setError($activity, $ex.getMessage());
        }

        protected function getSessionUser()
        {
            $user = \Application\Session::getCurrentUser();
            if ($user == null)
                throw new \Exception("Session has expired");
            return $user;
        }

    }

    class CH_Login_Command extends ClearingHouseCommand
    {
         function __construct() {
            parent::__construct(\Services\ActivityService::UseCase_Login);
            $this->entity_type_id = \Repository\ActivityRepository::User_Entity_Type;
         }

         function executeCommand($id, $payload = null)
         {
            return $this->locator->getSessionService()->login_session($payload["username"], $payload["password"], $payload["ip"]);
         }
    }

    class CH_Logout_Command extends ClearingHouseCommand
    {
         function __construct() {
            parent::__construct(\Services\ActivityService::UseCase_Logout);
            $this->entity_type_id = \Repository\ActivityRepository::User_Entity_Type;
         }

         function executeCommand($user_id, $payload = null)
         {
            return  $this->locator->getSessionService()->logout();
         }
    }


    class CH_Bootstrap_Command extends ClearingHouseCommand
    {
         function __construct() {
            parent::__construct(\Services\ActivityService::UseCase_Generic);
            $this->entity_type_id = 0;
         }

         function executeCommand($submission_id, $payload = null)
         {
            $service = new \Application\BootstrapService();

            $data = array(
                'Users' => $service->getUsersModel(),
                'Lookup' => array(
                    'RoleTypes' => $service->getUserRoleTypes(),
                    'RejectTypes' => $service->getRejectTypes(),
                    'DataProviderGradeTypes' => $service->getDataProviderGradeTypes(),
                    'LatestSites' => $service->getLatestUpdatedSites(),
                    'References' => $service->getInfoReferences(),
                    'DataSetListKeys' => $service->getDataSetListKeys(),
                    'Dummy' => "dummy"
                ),
                'Reports' => $service->getReports(),
                'Dummy' => "dummy"
            );
            return $data;
         }
    }

    class CH_Open_Command extends ClearingHouseCommand
    {
         function __construct() {
            parent::__construct(\Services\ActivityService::UseCase_Open_submission);
            $this->entity_type_id = \Repository\ActivityRepository::Submission_Entity_Type;
         }

         function executeCommand($submission_id, $payload = null)
         {
             return $this->locator->getSubmissionService()->getSubmissionMetaData($submission_id);
         }
    }

    class CH_Reject_Command extends ClearingHouseCommand
    {
         function __construct() {
            parent::__construct(\Services\ActivityService::UseCase_Reject_submission);
            $this->entity_type_id = \Repository\ActivityRepository::Submission_Entity_Type;
         }

         function executeCommand($submission_id, $payload = null)
         {
             return $this->locator->getRejectService()->execute($submission_id, $this->getSessionUser());
         }
    }

    class CH_Accept_Command extends ClearingHouseCommand
    {

         function __construct() {
            parent::__construct(\Services\ActivityService::UseCase_Accept_submission);
            $this->entity_type_id = \Repository\ActivityRepository::Submission_Entity_Type;
         }

         function executeCommand($submission_id, $payload = null)
         {
             return $this->locator->getAcceptService()->execute($submission_id, $this->getSessionUser());
         }
    }

    class CH_Claim_Command extends ClearingHouseCommand
    {

         function __construct() {
            parent::__construct(\Services\ActivityService::UseCase_Claim_submission);
            $this->entity_type_id = \Repository\ActivityRepository::Submission_Entity_Type;
         }

         function executeCommand($submission_id, $payload)
         {
             return $this->locator->getTransferService()->claim($submission_id);
         }
    }

    class CH_Unclaim_Command extends ClearingHouseCommand
    {

         function __construct() {
            parent::__construct(\Services\ActivityService::UseCase_Unclaim_submission);
            $this->entity_type_id = \Repository\ActivityRepository::Submission_Entity_Type;
         }

         function executeCommand($submission_id, $payload)
         {
             return $this->locator->getTransferService()->unclaim($submission_id);
         }
    }

    class CH_Transfer_Command extends ClearingHouseCommand
    {

         function __construct() {
            parent::__construct(\Services\ActivityService::UseCase_Transfer_submission);
            $this->entity_type_id = \Repository\ActivityRepository::Submission_Entity_Type;
         }

         function executeCommand($submission_id, $payload)
         {
             $receiving_user_id = $payload["user_id"];
             return $this->locator->getTransferService()->transfer($submission_id, $receiving_user_id);
         }
    }

    class CH_Save_Reject_Cause_Command extends ClearingHouseCommand
    {
         function __construct() {
            parent::__construct(\Services\ActivityService::UseCase_Add_reject_cause);
            $this->entity_type_id = \Repository\ActivityRepository::Submission_Entity_Type;
         }

         function executeCommand($submission_id, $payload)
         {
            $entity = $payload;
            if (is_object($entity["reject_entities"])) {
                $entity["reject_entities"] = get_object_vars($entity["reject_entities"]);
            }
            $this->locator->getSubmissionService()->saveSubmissionReject($submission_id, $entity);
            return $entity;
         }
    }

    class CH_Delete_Reject_Cause_Command extends ClearingHouseCommand
    {
         function __construct() {
            parent::__construct(\Services\ActivityService::UseCase_Delete_reject_cause);
            $this->entity_type_id = \Repository\ActivityRepository::Submission_Entity_Type;
         }

         function executeCommand($submission_id, $reject_id)
         {
             return $this->locator->getSubmissionService()->deleteSubmissionReject($reject_id);
         }
    }

    class CH_Save_User_Command extends ClearingHouseCommand
    {
         function __construct() {
            parent::__construct(\Services\ActivityService::UseCase_Update_user);
            $this->entity_type_id = \Repository\ActivityRepository::User_Entity_Type;
         }

         function executeCommand($user_id, $payload)
         {
            $entity = $payload;
            if ($user_id == 0) {
                $entity['create_time'] = \InfraStructure\Utility::Now();
            }
            $this->locator->getUserService()->saveUser($entity);
            return $entity;
         }
    }

    class CH_Process_Command extends ClearingHouseCommand
    {
         function __construct() {
            parent::__construct(\Services\ActivityService::UseCase_Process_submission);
            $this->entity_type_id = \Repository\ActivityRepository::Submission_Entity_Type;
         }

         function executeCommand($submission_id, $payload)
         {
            $submission = $this->registry->getSubmissionRepository()->findById($submission_id);
            try {
                $this->locator->getProcessor()->process($submission);
            } catch (\Exception $ex) {
                $this->registry->getSubmissionRepository()->saveError($submission, $ex->getMessage());
                throw $ex;
            }
            return $submission;
         }

    }

    class CH_Process_Queue_Command extends ClearingHouseCommand
    {
        function __construct() {
           parent::__construct(\Services\ActivityService::UseCase_Process_submission);
           $this->entity_type_id = \Repository\ActivityRepository::Submission_Entity_Type;
        }

        function executeCommand($dummy_id, $payload)
        {
            $submissions = $this->getQueue();
            foreach ($this->getQueue() as $key => $submission) {
               $this->getProcessCommand()->execute($submission["submission_id"], null);
            }
            return true;
        }

        public function getQueue() {
            return $this->registry->getSubmissionRepository()->findAllNew();
        }

        function getProcessCommand()
        {
            return new CH_Process_Command();
        }

    }


    class CH_Send_Reminder_Signal_Command extends ClearingHouseCommand
    {
         function __construct() {
            parent::__construct(\Services\ActivityService::UseCase_Send_Reminder);
            $this->entity_type_id = \Repository\ActivityRepository::Submission_Entity_Type;
         }

         function executeCommand($submission_id, $submission = null)
         {
             return $this->locator->getReminderService()->execute($submission, $this->getSessionUser());
         }
    }

    class CH_Reclaim_Submission_Command extends ClearingHouseCommand
    {
         function __construct() {
            parent::__construct(\Services\ActivityService::UseCase_Reclaim_Submission);
            $this->entity_type_id = \Repository\ActivityRepository::Submission_Entity_Type;
         }

         function executeCommand($submission_id, $submission = null)
         {
             return $this->locator->getReclaimService()->execute($submission, $this->getSessionUser());
         }
    }


    class CH_Nag_Command extends ClearingHouseCommand {

        function __construct() {
            parent::__construct(\Services\ActivityService::UseCase_Nag);
            $this->entity_type_id = \Repository\ActivityRepository::Generic_Entity_Type;
        }

        function executeCommand($no_id, $payload = null)
        {
             return $this->runNags();
        }

        public function runNags()
        {
            foreach ($this->getActiveSubmissions() as $submission) {
                $submission["activities"] = $this->registry->getActivityRepository()->findBySubmissionId($submission["submission_id"]);
                $submission["claim_user"] = $this->registry->getUserRepository()->findById($submission["claim_user_id"]);
                foreach ($this->getCommands() as $specification_command) {
                    $specification = $specification_command["specification"];
                    $command = $specification_command["command"];
                    if ($specification->IsSatisfiedBy($submission)) {
                        $command->execute($submission);
                        break;
                    }
                }
            }
            return true;
        }

        public function nag($submission)
        {
            $submission["activities"] = $this->registry->getActivityRepository()->findBySubmissionId($submission["submission_id"]);
            $submission["claim_user"] = $this->registry->getUserRepository()->findById($submission["claim_user_id"]);
            foreach ($this->getCommands() as $specification_command) {
                $specification = $specification_command["specification"];
                $command = $specification_command["command"];
                if ($specification->IsSatisfiedBy($submission)) {
                    $command->execute($submission);
                    break;
                }
            }
            return true;
        }

        function getActiveSubmissions()
        {
            return $this->registry->getSubmissionRepository()->find(array("submission_state_id" => \Model\Submission::State_InProgress));
        }

        function getCommands()
        {
            return array(
                array("specification" => $this->locator->getSendReminderSignalSpecification(), "command" => new \Application\CH_Send_Reminder_Signal_Command()),
                array("specification" => $this->locator->getTransferBackToPendingSpecification(), "command" => new \Application\CH_Reclaim_Submission_Command())
            );
        }

    }


}
?>