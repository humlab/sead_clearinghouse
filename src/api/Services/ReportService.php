<?php

namespace Services {

    class ReportService extends ServiceBase {

        function getReports()
        {
            return $this->registry->getReportRepository()->findAll();
        }

        function containsJson(&$data_columns)
        {
            $last_column = array_values(array_slice($data_columns, -1))[0];
            return (isset($last_column["native_type"]) && $last_column["native_type"] == 'json');
        }

        // TODO: Must make this a safer ID??
        function toUnderscored($label)
        {
            $result = trim($label);
            $result = \str_replace(':', '', $result);
            $result = \str_replace(' ', '_', $result);
            return trim($result);
        }

        function executeReport($id, $sid)
        {
            $data = $this->registry->getReportRepository()->execute($id, $sid);

            $data_values    = &$data["data"];
            $data_columns   = &$data["columns"];
            $report_columns = ReportColumnsBuilder::create($data_columns);

            if ($this->containsJson($data_columns)) {

                /* Crosstab report, get rid of json-column... */
                array_pop($data_columns);

                $json_columns = $this->extractJsonColumns($data_columns, $data_values);
                $report_columns = array_merge($report_columns, $json_columns);

                $this->extractJsonValues($data_values);
            }
            $result = array (
                "data" => $data_values,
                "columns" => $report_columns,
                "options" => array (
                    "paginate" => true
                )
            );

            return $result;
        }

        function getSubmissionTables($sid)
        {
            return $this->registry->getReportRepository()->getSubmissionTables($sid);
        }

        function getSubmissionTableContent($sid, $tableid)
        {
            $data = $this->registry->getReportRepository()->getSubmissionTableContent($sid, $tableid);

            $result = array (
                "data" => $data["data"],
                "columns" => ReportColumnsBuilder::create($data["columns"], false),
                "options" => array (
                    "paginate" => true
                )
            );
            return $result;

        }

        function extractJsonColumns(&$data_columns, &$values)
        {
            $column_names = \array_map(function ($x) { return $x["name"]; }, $data_columns);
            /* Extract column info from first data row */
            $json_columns = array();
            if (count($values) == 0) {
                /* no rows, return empty list */
                return $json_columns;
            }
            $json_values = json_decode(end($values[0]));
            foreach ($json_values as $key => $x) {
                $column_name = $this->toUnderscored($key);
                if (in_array($column_name, $column_names)) {
                     /* field also exists as non-json field -> skip it */
                     continue;
                }
                $json_columns[] = array(
                    "column_name" => $key,
                    "column_field" => $column_name,
                    "data_type" => "text", /* Always, only text, for now? */
                    "public_column_field" => 'public_' . $column_name,
                    "class" => "rotate-45"
                );
            }
            return $json_columns;
        }

        function extractJsonValues(&$values /*, &$column_names*/ ): void {
            foreach ($values as $value_key => &$value) {
                $json_values = json_decode(array_pop($value));
                foreach ($json_values as $key => $x) {
                    $column_name = $this->toUnderscored($key);
                    //if (in_array($column_name, $column_names)) {
                    //    continue;
                    //}
                    if (array_key_exists($column_name, $value)) {
                        continue;
                    }
                    if (\InfraStructure\Utility::endsWith($column_name, "_id")) {
                        continue;
                    }
                    $values[$value_key][$column_name] = $x != null ? htmlspecialchars_decode($x[2]) : null;
                    $values[$value_key]['public_' . $column_name] = $x != null ? htmlspecialchars_decode($x[3]) : null;
                }
            }
        }
    }

    class ReportColumnsBuilder
    {

        public static function create(&$data_columns, $ignore_id_columns=true, $ignore_json=true)
        {
            $review_columns = array();
            $column_names = \array_map(function ($x) { return $x["name"]; }, $data_columns);
            foreach ($data_columns as $data_column) {
                if (\InfraStructure\Utility::startsWith($data_column["name"], "public_")) {
                    continue;
                }
                if ($ignore_id_columns && \InfraStructure\Utility::endsWith($data_column["name"], "_id")) {
                    continue;
                }
                if ($ignore_json && $data_column["native_type"] == "json") {
                    continue;
                }
                $public_name = "public_" . $data_column["name"];
                $is_public_column = in_array($public_name, $column_names);
                $review_columns[] = ReportColumnsBuilder::createColumn($data_column, $is_public_column);
            }
            return $review_columns;
        }

        public static function createColumn(&$column_data, $is_public_column)
        {
            $column = array(
                "column_name"  => \InfraStructure\Utility::toCamelCase($column_data["name"], true, true),
                "column_field" => $column_data["name"],
                "data_type"    => $column_data["native_type"]
            );
            if ($is_public_column) {
                $column["public_column_field"] = "public_" . $column_data["name"];
            }
            return $column;
        }
    }
}
