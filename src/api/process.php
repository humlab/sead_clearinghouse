<?php

require_once __DIR__ . '/autoload.php';

$application = new \Application\Main();
$application->run();

$application->processSubmissionQueue();

?>