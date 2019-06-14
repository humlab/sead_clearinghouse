<?php

namespace Test {

    class ReadConfigTest {

        public function readEnvironmentVariables()
        {
            ini_set('auto_detect_line_endings', true);
            $filename = dirname(__FILE__) . "/docker.env";
            print($filename);
            if (!\file_exists($filename)) {
                throw new \Exception("File not found");
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
            var_dump($options);
        }
    }
    $reader =new ReadConfigTest();
    $reader->testCanReadConfig();
}
?>