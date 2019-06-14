<?php

namespace Test {
    
    class UnitTestBase extends \Services\ServiceBase
    {
        
    }
    
    class UnitTestService extends UnitTestBase {

        function map()
        {
            return array(
                'canruntest' => function() { echo "Test execution is enabled!"; },
                'cansavesubmission' => function() { (new \Test\SubmissionProcessTest())->testCanSaveSubmission(); },
                'canprocesssubmission' => function($arguments) { (new \Test\SubmissionProcessTest())->testCanProcessSubmission($arguments[1]); }
            );
        }

        function run($arguments)
        {
            //echo json_encode($arguments);
            $testcase = $arguments[0];

            $map = $this->map();
            if (!array_key_exists($testcase, $map)) {
                echo "Undefined testcase: " . json_encode($arguments) . " \n";
                die();
            }
            $map[$testcase]($arguments);
        }


    }
 

}
?>