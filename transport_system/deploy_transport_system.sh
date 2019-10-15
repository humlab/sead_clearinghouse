
#!/bin/bash

set -e  # Exit script on any error

script_name=`basename "$0"`
target_folder=
force=0
add_change_request=NO
add_to_git_clone=NO
sead_ccs_folder=
deploy_change_request=NO
deploy_target=
sqitch_command=./docker-sqitch.sh
target_project=general
script_folder=`pwd`

function usage() {
    echo "usage: $script_name [--force] [--add-change-request] "
    echo "       advanced option: [--target-folder=dir]  [--deploy-change-request] "
    echo ""
    echo "       --force                  Force overwrite of existing target folder if exists"
    echo "       --target-folder=dir      Override default target dir (not recommended)"
    echo "       --add-change-request     Add script to SEAD Control System"
    echo "       --sead-ccs-folder        Path to SEAD Control System"
    echo "       --add-to-git-clone       Deploy target (as defined in sqitch.conf"
    echo "       --deploy-change-request  Do deploy via the CCS system ton specified server and database"
    echo "       --deploy-target          Deploy target (as defined in sqitch.conf"
    exit 64
}

for i in "$@"; do
    case $i in
        --target-folder=*)
            target_folder="${i#*=}";
            shift ;;
        --force)
            force=1;
            shift ;;
        --add-change-request)
            add_change_request="YES";
            shift ;;
        --add-to-git-clone)
            add_to_git_clone="YES";
            shift ;;
        --sead-ccs-folder=*)
            sead_ccs_folder="${i#*=}";
            shift ;;
        --deploy-change-request)
            deploy_change_request="YES";
            shift ;;
        --deploy-target=*)
            deploy_target="${i#*=}";
            shift ;;
        --help)
            usage ;
            exit 0 ;;
       *)
        echo "error: unknown option $i" ;
        usage ;
        exit 0 ;
       ;;
    esac
done

if [ "$add_to_git_clone" == "YES" ]; then
    sead_ccs_folder=`pwd`/sead_change_control
fi

function get_cr_id() {
    day=$(date +%Y%m%d)
    cr_x="${day}_DDL_CLEARINGHOUSE_TRANSPORT_SYSTEM"
    echo "${cr_x^^}"
}

function generate_change_request() {

    crid=`get_cr_id`

    echo "/***************************************************************************" >> $target_folder/${crid}.sql
    echo "Author         $USER"                                                         >> $target_folder/${crid}.sql
    echo "Date           $day"                                                          >> $target_folder/${crid}.sql
    echo "Description    "                                                              >> $target_folder/${crid}.sql
    echo "Prerequisites  "                                                              >> $target_folder/${crid}.sql
    echo "Reviewer"                                                                     >> $target_folder/${crid}.sql
    echo "Approver"                                                                     >> $target_folder/${crid}.sql
    echo "Idempotent     YES"                                                           >> $target_folder/${crid}.sql
    echo "Notes          Use --single-transactin on execute!"                           >> $target_folder/${crid}.sql
    echo "***************************************************************************/" >> $target_folder/${crid}.sql

    echo "--set constraints all deferred;"                                              >> $target_folder/${crid}.sql
    echo "set client_min_messages to warning;"                                          >> $target_folder/${crid}.sql
    echo "-- set autocommit off;"                                                       >> $target_folder/${crid}.sql
    echo "-- begin;"                                                                    >> $target_folder/${crid}.sql

    cat ./01_setup_transport_schema.psql                                                >> $target_folder/${crid}.sql
    cat ./02_resolve_primary_keys.psql                                                  >> $target_folder/${crid}.sql
    cat ./03_resolve_foreign_keys.psql                                                  >> $target_folder/${crid}.sql
    cat ./04_script_data_transport.psql                                                 >> $target_folder/${crid}.sql

    echo "\$\$"                                                                         >> $target_folder/${crid}.sql
    echo "begin"                                                                        >> $target_folder/${crid}.sql
    echo "  perform clearing_house_commit.generate_sead_tables();"                      >> $target_folder/${crid}.sql
    echo "  perform clearing_house_commit.generate_resolve_functions('public', false);" >> $target_folder/${crid}.sql
    echo "end \$\$ language plpgsql;"                                                   >> $target_folder/${crid}.sql

	echo "-- commit;"                                                                   >> $target_folder/${crid}.sql

    echo "notice: change request has been generated to $target_folder"
}

function add_change_request_to_change_control_system()
{
    echo "notice: adding change request to ${sead_ccs_folder}..."
    crid=`get_cr_id`

    if [ ! -f $target_folder/${crid}.sql ]; then
        echo "failure: cannot add change request since $target_folder/${crid}.sql is missing"
        exit 64
    fi

    if [ == "YES" ]; then
        echo "warning: Cloning temporary git repo"
        rm -rf ./sead_change_control
        git clone https://github.com/humlab-sead/sead_change_control.git
    fi

    if [ ! -d $sead_ccs_folder ]; then
        echo "failure: cannot add change request since default CCS project folder $sead_ccs_folder is missing"
        exit 64
    fi

    if [ ! -x $sqitch_command ] && [ ! hash $sqitch_command 2>/dev/null ]; then
        echo "failure: command not found: $sqitch_command"
        exit 64
    fi

    current_folder=`pwd`

    cd $sead_ccs_folder

    target_deploy_file=$sead_ccs_folder/${target_project}/deploy/${crid}.sql

    if [ -f $target_deploy_file ]; then
        echo "failure: ccs task ${crid}.sql already exists (cannot resolve conflict)"
        exit 64
    fi

    chmod +x $sqitch_command

    $sqitch_command add --change-name ${crid} --note "Deploy of Clearinghouse Transport System." -C ./${target_project}

    if [ $? -ne 0 ];  then
        echo "fatal: sqitch add command failed." >&2
        exit 64
    fi

    cd $current_folder

    cp -f $target_folder/${crid}.sql $target_deploy_file

    echo "notice: change request ${crid} has been added to SEAD CSS repository!"
    echo "notice: please remember to commit repository!"
}

function deploy_change_request_to_target()
{
    crid=`get_cr_id`
    echo "notice: deploying change request to ${crid} to ${deploy_target}..."
    $sqitch_command deploy --target $deploy_target -C ./${target_project} ${crid}
}

if [ "$submission_id" == "0" ]; then
    usage ;
fi

if [ "$target_folder" == "" ]; then
    target_folder=`get_cr_id`
    echo "notice: storing data in $target_folder"
fi

if [ "$target_folder" == "" ]; then
    usage ;
fi

if [ "$add_change_request" == "NO" ] && [ "$deploy_change_request" == "YES" ]; then
    echo "usage: deploy can *only* be done in conjunction with ccs task creation (--add-ccs-task=YES --deploy-ccs-task=YES)"
    usage
fi

if [ "$deploy_target" == "" ] && [ "$deploy_change_request" == "YES" ]; then
    echo "usage: deploy sqitch deploy taget must be specified (--deploy-target)"
    usage
fi

if [ -d "$target_folder" ]; then
    if [ "$force" == "1" ]; then
        echo "notice: removing existing folder $target_folder"
        rm -f $target_folder/*.{sql,gz,txt,log}
        rmdir $target_folder
    else
        echo "error: folder exists! remove or use --force flag"
        exit 64
    fi
fi

mkdir -p $target_folder

generate_change_request

if [ "$add_change_request" == "YES" ]; then

    add_change_request_to_change_control_system

    if [ "$deploy_change_request" == "YES" ]; then
        deploy_change_request_to_target
    fi

fi


