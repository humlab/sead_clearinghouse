# -*- coding: utf-8 -*-
import os

extend = lambda a,b: a.update(b) or a
jj = os.path.join

db_opts = dict(
    database="sead_staging_clearinghouse",
    user=os.environ['SEAD_CH_USER'],
    password=os.environ['SEAD_CH_PASSWORD'],
    host="130.239.1.181",
    port=5432
)

source_folder = os.path.join(os.environ['HOMEPATH'], "Google Drive (roma0050@gapps.umu.se)\\Project\\Public\\VISEAD (Humlab)\\SEAD Ceramics & Dendro")

input_folder = os.path.join(source_folder, "input")
output_folder = os.path.join(source_folder, "output")

default_opt = dict(
    skip=False,
    input_folder=input_folder,
    output_folder=output_folder,
    meta_filename='metadata_latest.xlsx',
    table_names=None
)

run_opts = [
    extend(dict(default_opt), dict(
        skip=False,
        data_filename='ceramics_data_latest.xlsm',
        submission_id=0,
        # output_filename=jj(output_folder, 'ceramics_data_latest_20190527-115509_tidy.xml'),
        data_types='Ceramics'
    )),
    extend(dict(default_opt), dict(
        skip=False,
        submission_id=0,
        data_filename='dendro_ark_data_latest.xlsm',
        data_types='Dendro ARKEO'
    )),
    extend(dict(default_opt), dict(
        skip=False,
        submission_id=0,
        data_filename='dendro_build_data_latest.xlsm',
        data_types='Dendro BYGG')
    )
]

