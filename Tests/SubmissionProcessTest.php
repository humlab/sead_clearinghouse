<?php

namespace Test {
    

    class SubmissionProcessTest {
        
        public static function assertLoaded(){}

        public function testCanProcessSubmission($id)
        {
            \Services\SubmissionService::__classLoad();

            $registry = new \Repository\RepositoryRegistry();
            $submission = $registry->getSubmissionRepository()->findById($id);
            $service = new \Services\ProcessSubmissionService();

            $service->process($submission);
            
        }
        
        function testCanSaveSubmission()
        {
            
            \Services\SubmissionService::__classLoad();
            
            $registry = new \Repository\RepositoryRegistry();
            $submission = $registry->getSubmissionRepository()->findById(2);
            
            $submission[$id_column] = 0;
            $submission["xml"] = "test";
            
            $affected_columns = NULL;
            
            $registry->getSubmissionRepository()->save_table_record($submission, $affected_columns);
        }
    }  
    
    /*
    class DecodeProcessTest extends \Services\ServiceBase {
        
        function processSubmission($submissionId, $ignoreSubmissionProcessability = false){
            
            $submission = $this->registry->getSubmissionRepository()->findByIdX($submissionId);
            
            if (!$ignoreSubmissionProcessability && !$this->locator->getCanProcessSubmissionSpecification()->IsSatisfiesBy($submission)){
                throw new \Exception("ProcessSubmissionSpecification policy not satisfied");
            }
            
            $decoded = $this->locator->getXmlDecoder()->decode($submission["upload_content"]);
            return $decoded;
        }
        
    }
     * 
     */
    
}
?>