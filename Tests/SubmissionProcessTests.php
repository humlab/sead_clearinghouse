<?php

use PHPUnit\Framework\TestCase;

final class SubmissionProcessTests extends TestCase {

    public function testCanProcessSubmission($id)
    {
        \Services\SubmissionService::__classLoad();

        $registry = new \Repository\RepositoryRegistry();
        $submission = $registry->getSubmissionRepository()->findById($id);
        $service = new \Services\ProcessSubmissionService();

        $service->process($submission);

    }

    public function testCanSaveSubmission()
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
?>