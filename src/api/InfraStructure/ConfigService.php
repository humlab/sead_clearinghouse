<?php

namespace InfraStructure {

    class ConfigService {

        private static $database_config = null;
        private static $config = null;

        public static function getConfig()
        {
            if (self::$config == null) {
                self::$config = SettingService::getSettings();
            }
            return self::$config;
        }

        public static function getKeyValue($group, $key, $default)
        {
            try {
                return self::getConfig()[$group][$key];
            } catch (\Exception $ex) {
                return $default;
            }
        }

        public static function getDatabaseConfig()
        {
            return self::$database_config ?: ($database_config = self::readDatabaseConfig());
        }

        public static function readDatabaseConfig()
        {
            // if (strtoupper(substr(PHP_OS, 0, 3)) === 'WIN') {
                # return require $_SERVER['DOCUMENT_ROOT'] . '/../conf/credentials.php';

                return array(
                    "database" => getenv("CH_DATABASE"),
                    "hostname" => getenv("CH_HOST"),
                    "port" => getenv("CH_PORT"),
                    "username" => getenv("CH_USER"),
                    "password" => getenv("CH_PASSWORD")
                );

            // }
            // return require_once '/www/conf/clearing_house_database_conf.php';
        }
    }


    class SettingService {

        public static function getSettings()
        {
            $registry = \Repository\ObjectRepository::getObject('RepositoryRegistry');
            $config = array();
            foreach ($registry->getSettingRepository()->findAll() as $setting) {
                self::appendSetting($config, $setting);
            }
            return $config;
        }

        public static function appendSetting(&$config, $setting)
        {
            if ($setting["setting_group"] == "") {
                $config[$setting["setting_key"]] = self::getValue($setting);
            } else {
                if (!array_key_exists($setting["setting_group"], $config)) {
                    $config[$setting["setting_group"]] = array();
                }
                $config[$setting["setting_group"]][$setting["setting_key"]] = self::getValue($setting);
            }
            return $config;
        }

        public static function getValue($setting)
        {
            if ($setting["setting_datatype"] == "bool") {
                return $setting["setting_value"] == "true" || $setting["setting_value"] == "yes" || $setting["setting_value"] == "on";
            }
            if ($setting["setting_datatype"] == "numeric") {
                return is_numeric($setting["setting_value"]) ? intval($setting["setting_value"]) : 0;
            }
            return $setting["setting_value"];
        }

    }

}

?>