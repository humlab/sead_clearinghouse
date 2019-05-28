# -*- coding: utf-8 -*-
import os
import time
import io
import logging

from utility import setup_logger # pylint: disable=E0401
from repository import SubmissionRepository # pylint: disable=E0401
from parse_excel import process_excel_to_xml # pylint: disable=E0401

logger = logging.getLogger('Excel XML processor')

jj = os.path.join

class AppService:

    def __init__(self, db_opts):
        self.repository = SubmissionRepository(db_opts)

    def upload_xml(self, xml_filename, data_types=''):

        with io.open(xml_filename, mode="r", encoding="utf-8") as f:
            xml = f.read()

        submission_id = self.repository.add_xml(xml, data_types=data_types)

        return submission_id

    def process(self, options):

        for option in options:

            try:
                basename = os.path.splitext(option['data_filename'])[0]

                if option.get('skip', True) is True:
                    logger.info("Skipping: %s", basename)
                    continue

                timestamp = time.strftime("%Y%m%d-%H%M%S")

                log_filename = jj(option['output_folder'], '{}_{}.log'.format(basename, timestamp))
                setup_logger(logger, log_filename)

                logger.info('PROCESS OF %s STARTED', basename)

                submission_id = option.get("submission_id", 0)

                if submission_id == 0:

                    if option.get('output_filename', '') != '':
                        logger.info(' ---> USING EXISTING XML')
                        output_filename = option.get('output_filename', '')
                    else:
                        logger.info(' ---> PARSING EXCEL EXCEL')
                        output_filename = process_excel_to_xml(option, basename, timestamp)

                    logger.info(' ---> UPLOAD STARTED!')
                    submission_id = self.upload_xml(output_filename, data_types=option['data_types'])
                    logger.info(' ---> UPLOAD DONE ID=%s', submission_id)

                    logger.info(' ---> EXTRACT STARTED!')
                    self.repository.extract_submission(submission_id)
                    logger.info(' ---> EXTRACT DONE')

                else:
                    self.repository.delete_submission(submission_id, clear_header=False, clear_exploded=False)
                    logger.info(' ---> USING EXISTING DATA ID=%s', submission_id)

                logger.info(' ---> EXPLODE STARTED')
                self.repository.explode_submission(submission_id, p_dry_run=False, p_add_missing_columns=False)
                logger.info(' ---> EXPLODE DONE')

                self.repository.set_pending(submission_id)
                logger.info(' ---> PROCESS OF %s DONE', basename)

            except: # pylint: disable=W0702
                logger.exception('ABORTED CRITICAL ERROR %s ', basename)

if __name__ == "__main__":

    import argparse
    import importlib
    # parser = argparse.ArgumentParser(description='SEAD CH XML import')
    # parser.add_argument('-f','--optionfile', help='Import options filename without extension', required=True)
    # args = vars(parser.parse_args())
    # option_file = args['optionfile']

    option_file = 'run_opt_default'
    opts = importlib.import_module(option_file)

    logger.warning("Deploy target is %s on %s", opts.db_opts.get('database', '?'), opts.db_opts.get('host', '?'))

    AppService(opts.db_opts).process(opts.run_opts)
