
# SEAD Clearinghouse Commit and Deploy Sub-system

SEAD sub-system that deploys a SEAD clearinghouse submission to the public SEAD database via the SEAD Change Control System (SEAD CCS).

## Approach and Postulates

The system creates a complete `SEAD CCS` using the following steps:
    1. Create a copy out SQL script that exports all the data into compressed text files
    2. Runs the copy out script
    3. Creates a copy in script that can be used as a SEAD CCS task
    4. Optionally: Creates a SEAD CCS task
    5. Optionally: Deploys the SEAD CCS to a `sqitch` target

The export and import are carried out using client side psql `\copy` commands. All files are hence stored locally.

# Installation

Please make sure that you have an up-to-date local (clones) copy of the SEAD Clearinghouse source code. It can be checked out from `https://github.com/humlab-sead/sead_clearinghouse.git`.
    1. `cd path-to-source/sql/transport_system`
    2. `chmod +x ./install_transport_system.bash`
    3. `./install_transport_system.bash --dbhost="sead-server" --dbname="target-database"`

The installation creates (or recreates) schema `clearing_house_commit' consisting of all the necessary scripts. The schema contains not data, just functions and views.

## How to execute


