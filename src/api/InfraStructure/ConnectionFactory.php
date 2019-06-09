<?php

namespace InfraStructure {

    use PDO;

    class ConnectionFactory {

        public static function Create($options)
        {
            $hostname = $options["CH_HOST"];
            $port     = $options["CH_PORT"];
            $username = $options["CH_USER"];
            $password = $options["CH_PASSWORD"];
            $database = $options["CH_DATABASE"];
            return new DatabaseConnection("pgsql:dbname=$database;host=$hostname;port=$port", $username, $password, array(PDO::ATTR_PERSISTENT => true));
        }

        // public static function CreateDefault()
        // {
        //     return ConnectionFactory::Create(DatabaseConfig::getConfig());
        // }
    }

    class DatabaseConfig {

        public static function GetConfig()
        {
            return \InfraStructure\ConfigService::getDatabaseConfig();
        }
    }


}

?>
