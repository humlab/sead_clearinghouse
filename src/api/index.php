<?php

require __DIR__ . '/autoload.php';

use Application\Main;
use Application\Router;

$application = new Main();
$application->run();

$router = new Router($application);
$router->run();

?>