/* KILL ALL EXISTING CONNECTION FROM ORIGINAL DB (sourcedb)*/
SELECT pg_terminate_backend(pg_stat_activity.pid)
FROM pg_stat_activity 
WHERE pg_stat_activity.datname = 'sead_staging'
  AND pid <> pg_backend_pid();

/* CLONE DATABASE TO NEW ONE(TARGET_DB) */
CREATE DATABASE sead_dev_clearinghouse WITH TEMPLATE sead_staging OWNER sead_master;

SELECT datname, temp_files AS "Temporary files", temp_bytes AS "Size of temporary files", *
FROM   pg_stat_database db;
/* Try to remove temp. files (used by running queries) */
CHECKPOINT;
CHECKPOINT;
VACUUM sead_master_9_ceramics;
VACUUM (FULL) sead_master_9_ceramics;
VACUUM (FULL, ANALYZE) sead_master_9_ceramics;

-- update clearing_house.tbl_clearinghouse_submissions set xml = NULL;
-- vacuumdb --full --echo --verbose --analyze --dbname=sead_master_9_ceramics -U postgres -h localhost
-- SHOULD BE DONE AFTER IMPORT:
Truncate Table clearing_house.tbl_clearinghouse_submission_xml_content_values;
Truncate Table clearing_house.tbl_clearinghouse_submission_xml_content_columns;
Truncate Table clearing_house.tbl_clearinghouse_submission_xml_content_records;
Truncate Table clearing_house.tbl_clearinghouse_submission_xml_content_tables;
	