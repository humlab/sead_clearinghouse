<?php

namespace Services {
    
    class ReportService extends ServiceBase {

        function getReports()
        {
            return $this->registry->getReportRepository()->findAll();
        }

        function executeReport($id, $sid)
        {
            $data = $this->registry->getReportRepository()->execute($id, $sid);
            
            $result = array (
                "data" => $data["data"],
                "columns" => ReportColumnsBuilder::createReviewTableColumns($data["columns"]),
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
                "columns" => ReportColumnsBuilder::createReviewTableColumns($data["columns"], false),
                "options" => array (
                    "paginate" => true
                )
            );
            return $result;
            
        }
        
    }
    
    class ReportColumnsBuilder
    {
        public static function createDataTablesColumns($columns)
        {
             return  array_map(
                        function ($x) {
                            return array(
                                "column_name" => $x["name"],
                                "data_type" => $x["native_type"]
                            );
                        },
                    $columns
            );
        }
        
        public static function createReviewTableColumns($columns, $ignore_id_columns = true)
        {
            $review_columns = array();
            $column_names = \array_map(function ($x) { return $x["name"]; }, $columns);
            foreach ($columns as $column) {
                if (\InfraStructure\Utility::startsWith($column["name"], "public_")) {
                    continue;
                }
                if ($ignore_id_columns && \InfraStructure\Utility::endsWith($column["name"], "_id")) {
                    continue;
                }
                $column_data = array();
                $column_data["column_name"] = \InfraStructure\Utility::toCamelCase($column["name"], true, true);
                $column_data["column_field"] = $column["name"];
                $column_data["data_type"] = $column["native_type"];
                $public_name = "public_" . $column["name"];
                if (in_array ($public_name, $column_names)) {
                    $column_data["public_column_field"] = $public_name;
                }
                $review_columns[] = $column_data;
            }
            
            return $review_columns;
        }      


    }
}

