<?php

#require_once __DIR__ . '/class_loader.php';

require __DIR__ . '/../vendor/autoload.php';

#$loader = new ClassLoaderService();
#$loader->setup();

use Application\Main;
use Application\Router;

$application = new Main();
$application->run();

$router = new Router($application);
$router->run();


?>