
### How to install SEAD Clearinghouse DB schema

Script "install_clearinghouse_database.bash" creates a `clearing_house` schema on the target database that containing required tables, functions and data.
Please note that:

- The script must be run as database user `clearinghouse_worker`
- The script will abort if `clearing_house` schema already exists on server

Note! Schema "clearing_house" will be recreated from scratch!

