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
            return self::$database_config ?: ($database_config = self::readDatabaseConfigFromEnvironment());
        }

        public static function readDatabaseConfigFromEnvironment()
        {
            if (\InfraStructure\ConfigService::envConfigSet()) {
                return array(
                    "CH_DATABASE" => getenv("CH_DATABASE"),
                    "CH_HOST" => getenv("CH_HOST"),
                    "CH_PORT" => getenv("CH_PORT"),
                    "CH_USER" => getenv("CH_USER"),
                    "CH_PASSWORD" => getenv("CH_PASSWORD")
                );
            }
            return false;
        }

        public static function readDatabaseConfigFromFile()
        {
            $filename = "/etc/.pgpass.env";
            ini_set('auto_detect_line_endings', true);
            if (!\file_exists($filename)) {
                return NULL;
            }
            $text = file_get_contents($filename);
            $lines = explode("\n",$text);
            $options = array();
            foreach ($lines as $line) {
                $keyvalue = explode("=", $line);
                if ($keyvalue[0] !== "") {
                    $options[trim($keyvalue[0])] = trim($keyvalue[1]);
                }
            }
            return $options;
        }

        public static function envConfigSet()
        {
            return getenv("CH_DATABASE") &&
                   getenv("CH_HOST") &&
                   getenv("CH_PORT") &&
                   getenv("CH_USER") &&
                   getenv("CH_PASSWORD");
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