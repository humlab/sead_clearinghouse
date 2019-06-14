<?php

class ClassBootstrapService
{
    function map()
    {
        $api_dir =  __DIR__ . '/../src/api/';
        return array(
            'Application' => $api_dir,
            'InfraStructure' => $api_dir,
            'Repository' => $api_dir,
            'Services' => $api_dir,
            'Model' => $api_dir,
            'Test' => $api_dir
        );
    }

    function setup()
    {
        $autoloader =  __DIR__ . '/../public/vendor/autoload.php';
        require_once $autoloader;
        return $this;
    }

}

$loader = new ClassBootstrapService();
$loader->setup();

?>
