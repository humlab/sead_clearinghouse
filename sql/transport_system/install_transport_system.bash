#!/bin/bash

set -e

if [ -f ~/vault/.default.sead.server ]; then
    dbhost=$(head -n 1 ~/vault/.default.sead.server)
fi

script_name=`basename "$0"`
dbuser=humlab_admin
dbport=5432
dbname=

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

function usage() {
    echo "usage: $script_name [--dbhost=target-server] [--port=port] [--dbname=target-database]"
    exit 64
}

function check_install_options() {

    if [ "$dbuser" != "humlab_admin" ]; then
        echo "fatal: script must be rub by user humlab_admin." >&2
        exit 64
    fi
    if [ "$dbhost" == "" ] || [ "$dbname" == "" ]; then
        usage
    fi
}

function install_transport_system() {
    psql --host=$dbhost --port=$dbport --username=$dbuser --dbname=$dbname --no-password -q -1 -v ON_ERROR_STOP=1 <<EOF

        set client_min_messages to warning;

        \i '01_setup_transport_schema.psql'
        \i '02_resolve_primary_keys.psql'
        \i '03_resolve_foreign_keys.psql'
        \i '04_script_data_transport.psql'

        do \$\$
        begin
            perform clearing_house_commit.generate_sead_tables();
            perform clearing_house_commit.generate_resolve_functions('public', false);
        end \$\$ language plpgsql;
EOF
}

echo "Deploying SEAD Clearinghouse transport system using URI $dbuser@$dbhost:$dbport/$dbname"
echo -n " Running install..."
check_install_options
install_transport_system
echo "done!"
