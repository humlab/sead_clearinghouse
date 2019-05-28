#!/bin/bash

#EXPORT PGOPTIONS='--client-min-messages=warning'

dbhost=$(head -n 1 ~/vault/.default.sead.server)
#dbuser=$(head -n 1 ~/vault/.default.sead.username)
dbuser=clearinghouse_worker
dbport=5432
dbname=sead_staging_clearinghouse

for i in "$@"; do
    case $i in
        -h=*|--dbhost=*)
            dbhost="${i#*=}";
            shift;;
        -p=*|--port=*)
            dbport="${i#*=}";
            shift ;;
        -d=*|--dbname=*)
            dbname="${i#*=}";
            shift;;
        -u=*|--dbuser=*)
            dbuser="${i#*=}";
            shift ;;
        *);;
    esac
done
echo "Deploy target ${DBNAME} on ${dbhost}"
echo "psql --host=$dbhost --port=$dbport --username=$dbuser --dbname=$dbname -"

psql --host=$dbhost --port=$dbport --username=$dbuser --dbname=$dbname --no-password -q -X -1 -v ON_ERROR_STOP=1 <<EOF
    SET client_min_messages TO WARNING;

    \i '00 - create_schema.sql'
    \i '00 - utility_functions.sql'
    \i '01 - transfer_sead_rdb_schema.sql'
    \i '02 - create_clearing_house_data_model.sql'
    \i '02 - populate_clearing_house_data_model.sql'

    SELECT clearing_house.fn_dba_create_clearing_house_db_model(FALSE);
    SELECT clearing_house.fn_dba_populate_clearing_house_db_model();

    \i '03 - create_rdb_entity_data_model.sql'

    SELECT clearing_house.fn_create_clearinghouse_public_db_model(FALSE, FALSE);

    \i '04 - explode_submission_xml_to_rdb.sql'
    \i '05 - client_review_crosstab_ceramic_values.sql'
    \i '05 - client_review_dataset_data_procedures.sql'
    \i '05 - client_review_sample_data_procedures.sql'
    \i '05 - client_review_sample_group_data_procedures.sql'
    \i '05 - client_review_site_data_procedures.sql'
    \i '05 - report_procedures.sql'

    GRANT clearinghouse_worker TO mattias;
EOF

psql --host=$dbhost --port=$dbport --username=humlab_admin --dbname=$dbname --no-password -q -X -1 -v ON_ERROR_STOP=1 <<EOF

    alter user clearinghouse_worker createdb;
    grant all privileges on database sead_staging_clearinghouse to clearinghouse_worker;

    grant connect on database sead_staging_clearinghouse to clearinghouse_worker;
    grant usage on schema public, sead_utility to clearinghouse_worker;
    grant all privileges on all tables in schema public, sead_utility to clearinghouse_worker;
    grant all privileges on all sequences in schema public, sead_utility to clearinghouse_worker;
    grant execute on all functions in schema public, sead_utility to clearinghouse_worker;

    alter default privileges in schema public, sead_utility
    grant all privileges on tables to clearinghouse_worker;
    alter default privileges in schema public, sead_utility
    grant all privileges on sequences to clearinghouse_worker;

EOF

