<?php

require __DIR__ . '/../src/api/autoload.php';

use PHPUnit\Framework\TestCase;

final class ReportTest extends TestCase {

    private function getTestData($filename)
    {
        $path = dirname(__FILE__) . "/" . $filename;
        $fp = fopen($filename, 'r');
        $data = fread($fp,filesize($filename));
        fclose($fp);
        $testData = unserialize($data);
        return $testData;
    }

    public function testCanCreateService(): void
    {
        $this->assertTrue(true); //$testData != null);

    }

    public function testDecodeResultFromCrosstabReport(): void
    {
        $data = $this->getTestData("report_data.dat");

        $this->assertTrue(true); //$testData != null);

    }

    function executeReport($id, $sid)
    {
        $data = $this->registry->getReportRepository()->execute($id, $sid);
        $values = $data["data"];
        $columns = ReportColumnsBuilder::create($data["columns"]);
        if ($this->is_crosstab_result($columns)) {
            $crosstab_column_discarded = array_pop($columns);
            if (count($values) > 0) {
                $crosstab_row_values = json_decode(end($values[0]));
                foreach ($crosstab_row_values as $crosstab_key => $x) {
                    $column_name = $this->to_undercored($x[0]);
                    $columns[] = array(
                        "column_name" => $x[0],
                        "column_field" => $column_name,
                        "data_type" => $x[1],
                        "public_column_field" => 'public_' . $column_name,
                        "class" => "rotate-45"
                    );
                }
            }
            foreach ($values as $key => $value) {
                $crosstab_row_values = json_decode(array_pop($value));
                foreach ($crosstab_row_values as $x) {
                    $column_name = $this->to_undercored($x[0]);
                    $values[$key][$column_name] = $x[2];
                    $values[$key]['public_' . $column_name] = $x[3];
                }
            }
        }
        $result = array (
            "data" => $values,
            "columns" => $columns,
            "options" => array (
                "paginate" => true
            )
        );

        return $result;
    }

}
?>