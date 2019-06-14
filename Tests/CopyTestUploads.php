<?php

namespace Test {
    
    class CopyTestUploads {

        public function copyData()
        {

            $db1 = \InfraStructure\ConnectionFactory::Create(array(
                "hostname" => "snares.idesam.umu.se",
                "port" => "12343",
                "username" => "roger",
                "password" => "rogerHumlab",
                "database" => "sead_master6_testing")
            );
            
            $db2 = \InfraStructure\ConnectionFactory::CreateDefault();

            $data = $db1->fetch_all("select * From metainformation.tbl_upload_contents where upload_content_id = 81", null);

            $stmt = $db2->prepare("Insert Into clearing_house.tbl_clearinghouse_submissions (upload_user_id, submission_state_id, data_types, upload_date, upload_content, xml) Values (:upload_user_id, :submission_state_id, :data_types, :upload_date, :upload_content, null)");   

            foreach ($data as $row) {

                $user_id = 4;
                $submission_state_id = 1;

                $stmt->bindParam(':upload_user_id', $user_id /* test_normal $row["upload_user_id"] */);
                $stmt->bindParam(':submission_state_id', $submission_state_id);
                $stmt->bindParam(':data_types', $row["upload_data_types"]);
                $stmt->bindParam(':upload_date', $row["upload_date"]);
                $stmt->bindParam(':upload_content', $row["upload_contents"]);

                echo "Executing...";
                $stmt->execute();

            }

            //echo json_encode($data);

            echo "...done!";

        }
    }   
}
?>