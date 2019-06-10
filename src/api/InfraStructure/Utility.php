<?php

namespace InfraStructure {

    class Utility {

        public static function objectToArray($d) {

            if (is_object($d)) {
                $d = get_object_vars($d);
            }

            if (is_array($d)) {
                return array_map(function ($x) { return \InfraStructure\Utility::objectToArray($x); }, $d);
            }

            return $d;
        }

        public static function Now()
        {
            return (new \DateTime('NOW'))->format('c');
        }

        public static function startsWith($haystack,$needle)
        {
            return strncmp($haystack, $needle, strlen($needle)) === 0;
        }

        public static function endsWith($haystack, $needle)
        {
            return $needle === "" || substr($haystack, -strlen($needle)) === $needle;
        }

          /**
         * Translates a camel case string into a string with underscores (e.g. firstName -&gt; first_name)
         * @param    string   $str    String in camel case format
         * @return    string            $str Translated into underscore format
         */
        public static function toUnderscore($str) {
            $str[0] = strtolower($str[0]);
            $func = create_function('$c', 'return "_" . strtolower($c[1]);');
            return preg_replace_callback('/([A-Z])/', $func, $str);
        }

        /**
         * Translates a string with underscores into camel case (e.g. first_name -&gt; firstName)
         * @param    string   $str                     String in underscore format
         * @param    bool     $capitalise_first_char   If true, capitalise the first char in $str
         * @return   string                              $str translated into camel caps
         */
        public static function toCamelCase($str, $capitalise_first_char = false, $add_space = false) {
            if ($capitalise_first_char) {
                $str[0] = strtoupper($str[0]);
            }
            $space = $add_space ? " " : "";
            $func = function($c) use ($space) {
                return $space . strtoupper($c[1]);
            };
            return preg_replace_callback('/_([a-z])/', $func, $str);
        }

//        function assoc2indexedMulti($array) {
//            $index_array = array();
//            foreach($array as $value) {
//                if(is_array($value)) {
//                    $index_array[] = $this->assoc2indexedMulti($value);
//                } else {
//                    $index_array[] = $value;
//                }
//            }
//            return $index_array;
//        }

        function utf8_encode_recursive($data)
        {
            if (is_string($data)) {
                return utf8_encode($data);
            }
            if (!is_array($data)) {
                return $data;
            }
            return array_map(function ($x) { return \InfraStructure\Utility::utf8_encode_recursive($x); }, $data);
        }

//        function utf8_decode($dat)
//        {
//          if (is_string($dat)) return utf8_decode($dat);
//          if (!is_array($dat)) return $dat;
//          $ret = array();
//          foreach($dat as $i=>$d) $ret[$i] = utf8_decode_all($d);
//          return $ret;
//        }

        public static function getServerIP()
        {
            return $_SERVER['REMOTE_ADDR'];
        }

    }
}

?>