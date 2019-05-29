#!/bin/bash

set -e  # Exit script on any error

#EXPORT PGOPTIONS='--client-min-messages=warning'

dbhost=$(head -n 1 ~/vault/.default.sead.server)
dbuser=clearinghouse_worker
dbport=5432
dbname=sead_staging_20190521071657

on_schema_exists=abort

for i in "$@"; do
    case $i in
        -h=*|--dbhost=*)
            dbhost="${i#*=}"; shift;;
        -p=*|--port=*)
            dbport="${i#*=}"; shift ;;
        -d=*|--dbname=*)
            dbname="${i#*=}"; shift ;;
        -u=*|--dbuser=*)
            dbuser="${i#*=}"; shift ;;
        -x|--on-schema-exists=*)
            on_schema_exists="${i#*=}"; shift ;;
       *);;
    esac
done

function dbexec() {
    database=$1
    username=$2
    sql=$3
    psql --host=$dbhost --username=$username --no-password --dbname=$database -q -X -1 -v ON_ERROR_STOP=1 --command "$sql"
    if [ $? -ne 0 ];  then
        echo "FATAL: Deploy aborted." >&2
        echo "FATAL: psql command failed!" >&2
        echo "$sql" >&2
        exit 64
    fi
}

function drop_schema() {
    echo "Dropping schema..."
    sql="drop schema if exists clearing_house cascade;"
    dbexec "$dbname" "clearinghouse_worker" "$sql"
}

function create_schema() {
    echo "Creating schema..."
    sql="create schema clearing_house;"
    dbexec "$dbname" "clearinghouse_worker" "$sql"
}

echo "Deploying SEAD Clearinghouse on \"${dbhost}\" database \"${dbname}\"..."
echo "Using settings --host=$dbhost --port=$dbport --username=$dbuser --dbname=$dbname --on-schema-exists=$on_schema_exists"
echo "Note: user clearinghouse_worker must exist on target server"

if [ "$dbuser" != "clearinghouse_worker" ]; then
    echo "FATAL: clearinghouse DB must be initialized by user clearinghouse_worker." >&2
    exit 64
fi

echo "Setting worker permissions..."
psql --host=$dbhost --port=$dbport --username=humlab_admin --dbname=$dbname --no-password -q -X -1 -v ON_ERROR_STOP=1 <<EOF

    alter user clearinghouse_worker createdb;
    grant all privileges on database $dbname to clearinghouse_worker;
    grant connect on database $dbname to clearinghouse_worker;

EOF

sql="select exists(select from information_schema.schemata where schema_name = 'clearing_house')"
schema_exists=$( psql --host=$dbhost --username=$dbuser --no-password --dbname=$dbname -tAc "$sql" )
if [ "$schema_exists" = 't' ]
then
    if [ "$on_schema_exists" == "drop" ]; then
        drop_schema
        create_schema
    elif [ "$on_schema_exists" == "update" ]; then
        echo "Action: Update of existing database requested"
    else
        echo "FATAL: Schema exists, use --on-schema-exists=[drop|update] to resolve conflict"
        exit 64
    fi
else
    create_schema
fi

psql --host=$dbhost --port=$dbport --username=$dbuser --dbname=$dbname --no-password -q -X -1 -v ON_ERROR_STOP=1 <<EOF

    set client_min_messages to warning;

    \i '01 - utility_functions.sql'
    \i '02 - create_clearing_house_data_model.sql'
    
    \i '02 - populate_clearing_house_data_model.sql'

    select clearing_house.fn_dba_create_clearing_house_db_model(false);
    select clearing_house.fn_dba_populate_clearing_house_db_model();

    \i '03 - create_rdb_entity_data_model.sql'

    select clearing_house.fn_create_clearinghouse_public_db_model(false, false);

    \i '04 - explode_submission_xml_to_rdb.sql'
    \i '05 - client_review_crosstab_ceramic_values.sql'
    \i '05 - client_review_dataset_data_procedures.sql'
    \i '05 - client_review_sample_data_procedures.sql'
    \i '05 - client_review_sample_group_data_procedures.sql'
    \i '05 - client_review_site_data_procedures.sql'
    \i '05 - report_procedures.sql'

    grant clearinghouse_worker to mattias;

EOF

if [ $? -ne 0 ];  then
    echo "FATAL: psql command failed! Deploy aborted." >&2
    exit 64
fi

psql --host=$dbhost --port=$dbport --username=humlab_admin --dbname=$dbname --no-password -q -X -1 -v ON_ERROR_STOP=1 <<EOF

    grant usage on schema public, sead_utility to clearinghouse_worker;
    grant all privileges on all tables in schema public, sead_utility to clearinghouse_worker;
    grant all privileges on all sequences in schema public, sead_utility to clearinghouse_worker;
    grant execute on all functions in schema public, sead_utility to clearinghouse_worker;

    alter default privileges in schema public, sead_utility
    grant all privileges on tables to clearinghouse_worker;
    alter default privileges in schema public, sead_utility
    grant all privileges on sequences to clearinghouse_worker;

EOF

if [ $? -ne 0 ];  then
    echo "FATAL: psql command failed! Deploy aborted." >&2
    exit 64
fi
