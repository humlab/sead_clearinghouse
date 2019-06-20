# -*- coding: utf-8 -*-
import os
import pandas as pd
import numpy as np
import logging
from functools import reduce
from utility import flatten_sets, setup_logger

logger = logging.getLogger('Excel XML processor')
setup_logger(logger)

jj = os.path.join

class DataImportError(Exception):
    '''
    Base class for other exceptions
    '''
    pass

class MetaData:

    '''
    Logic related to meta-data read from Excel file
    '''
    def __init__(self):
        self.Tables = None
        self.Columns = None
        self.PrimaryKeys = None
        self.ForeignKeys = None
        self.ForeignKeyAliases = {
            'updated_dataset_id': 'dataset_id'
        }
        self._ForeignKey_Hash = None
        self._PrimaryKey_Hash = None
        self._Classname_Cache = None

    def load(self, filename):

        def recode_excel_sheet_name(row):
            value = row['excel_sheet']
            if pd.notnull(value) and len(value) > 0 and value != 'nan':
                logger.info("Using alias %s for %s", value, row['table_name'])
                return value
            return row['table_name']

        self.Tables = pd.read_excel(filename, 'Tables',
            dtype={
                'table_name': 'str',
                'java_class': 'str',
                'pk_name': 'str',
                'excel_sheet': 'str',
                'notes': 'str'
            })

        self.Columns = pd.read_excel(filename, 'Columns',
            dtype={
                'table_name': 'str',
                'column_name': 'str',
                # 'position': np.int32,
                'nullable': 'str',
                'type': 'str',
                # 'length': np.int32,
                # 'size': np.int32,
                'type2': 'str',
                'class': 'str'
            })  # .set_index(['table_name', 'column_name'])

        self.Tables['table_name_index'] = self.Tables['table_name']
        self.Tables = self.Tables.set_index('table_name_index')

        self.Tables['excel_sheet'] = self.Tables.apply(recode_excel_sheet_name, axis=1)

        self.PrimaryKeys = pd.merge(self.Tables, self.Columns, how='inner', left_on=['table_name', 'pk_name'], right_on=['table_name', 'column_name'])[['table_name', 'column_name', 'java_class']]
        self.PrimaryKeys.columns = ['table_name', 'column_name', 'class_name']

        self.ForeignKeys = pd.merge(self.Columns, self.PrimaryKeys, how='inner', left_on=['column_name', 'class'], right_on=['column_name', 'class_name'])[['table_name_x', 'table_name_y', 'column_name', 'class_name' ]]
        self.ForeignKeys = self.ForeignKeys[self.ForeignKeys.table_name_x != self.ForeignKeys.table_name_y]

        self._ForeignKey_Hash = {
            x: True for x in list(self.ForeignKeys.table_name_x + '#' + self.ForeignKeys.column_name)
        }

        self._PrimaryKey_Hash = {
            x: True for x in self.Tables.table_name + '#' + self.Tables.pk_name
        }

        self._Classname_Cache = self.Tables.set_index('java_class')['table_name'].to_dict()
        return self

    @property
    def tablenames(self):
        return self.Tables["table_name"].tolist()

    def table_fields(self, table_name):
        return self.Columns[(self.Columns.table_name == table_name)]

    # def get_columns(self, table_name):
    #     return self.Columns[(self.Columns.table_name == table_name)].to_dict()

    def is_table(self, table_name):
        return table_name in self.Tables.table_name.values

    def get_table(self, table_name):
        return self.Tables.loc[table_name].to_dict()

    def get_tablename_by_classname(self, class_name):
        try:
            if '.' in class_name:
                class_name = class_name.split('.')[-1]
            # return self.Tables.loc[(self.Tables.java_class == class_name)]['table_name'].iloc[0]
            return self._Classname_Cache[class_name]
        except: # pylint: disable=W0702
            logger.warning('get_tablename_by_classname Unknown class: %s', class_name)
            return None

    def is_fk(self, table_name, column_name):
        if column_name in self.ForeignKeyAliases:
            return True
        return (table_name + '#' + column_name) in self._ForeignKey_Hash
        # return ((self.Tables.table_name != table_name) & (self.Tables.pk_name == column_name)).any()

    def is_pk(self, table_name, column_name):
        return (table_name + '#' + column_name) in self._PrimaryKey_Hash
        # return ((self.Tables.table_name == table_name) & (self.Tables.pk_name == column_name)).any()

    def get_pk_name(self, table_name):
        try:
            return self.PrimaryKeys.loc[(self.PrimaryKeys.table_name == table_name)]['column_name'].iloc[0]
        except: # pylint: disable=W0702
            return None

    def get_classname_by_tablename(self, table_name):
        return self.PrimaryKeys.loc[(self.PrimaryKeys.table_name == table_name)]['class_name'].iloc[0]

    def get_tablenames_referencing(self, table_name):
        return self.ForeignKeys.loc[(self.ForeignKeys.table_name_y == table_name)]['table_name_x'].tolist()

class ValueData:

    '''
    Logic dealing with the data (load etc)
    '''
    def __init__(self, metaData):
        self.MetaData = metaData
        self.DataTables = None
        self.DataTableIndex = None

    def load(self, source):

        reader = pd.ExcelFile(source) if isinstance(source, str) else source

        def load_sheet(sheetname):
            df = None
            try:
                df = reader.parse(sheetname)
            except: # pylint: disable=W0702
                pass
            logger.info('SHEET %s: %s', sheetname, 'READ' if df is not None else 'NOT FOUND')
            return df

        self.DataTables = {
            x['table_name']: load_sheet(x['excel_sheet']) for i, x in self.MetaData.Tables.iterrows()
        }
        self.DataTableIndex = load_sheet('data_table_index')
        if self.DataTableIndex is None:
            logger.exception('Data file has no data table index')
        reader.close()
        self.update_system_id()
        return self

    def store(self, filename):
        writer = pd.ExcelWriter(filename)
        for (table_name, df) in self.DataTables:
            df.to_excel(writer, table_name)  # , index=False)
        writer.save()
        return self

    def exists(self, table_name):
        return table_name in self.DataTables.keys() and self.DataTables[table_name] is not None

    def has_system_id(self, table_name):
        return self.exists(table_name) and 'system_id' in self.DataTables[table_name].columns

    @property
    def tablenames(self):
        return [ x for x in self.DataTables.keys() if self.exists(x) ]

    @property
    def data_tablenames(self):
        # return self.MetaData.tables_with_data()
        return self.DataTableIndex["table_name"].tolist()

    def cast_table(self, table_name):
        data_table = self.ValueData.Tables[table_name]
        fields = self.MetaData.table_fields(table_name)
        for _, item in fields.iterrows():
            column = item.to_dict()
            if column['column_name'] in data_table.columns:
                if column['type'] in ['integer']:
                    self.ValueData.Tables[table_name].astype(np.int64)

    def update_system_id(self):

        for table_name in self.data_tablenames:
            try:
                data_table = self.DataTables[table_name]
                table_definition = self.MetaData.get_table(table_name)

                pk_name = table_definition['pk_name']

                if pk_name == 'ceramics_id':
                    pk_name = 'ceramic_id'

                if data_table is None or pk_name not in data_table.columns:
                    continue

                if 'system_id' not in data_table.columns:
                    raise DataImportError('CRITICAL ERROR Table {} has no column named "system_id"'.format(table_name))

                data_table.loc[np.isnan(data_table.system_id), 'system_id'] = data_table.loc[np.isnan(data_table.system_id), pk_name]
                # Change 20180628: Set system_id as index for fast
                # data_table.set_index('system_id', drop=False, inplace=True)
            except DataImportError as _:
                logger.exception('update_system_id')
                continue
        return self

    def get_referenced_keyset(self, table_name):
        pk_name = self.MetaData.get_pk_name(table_name)
        if pk_name is None:
            return []
        ref_tablenames = self.MetaData.get_tablenames_referencing(table_name)
        sets_of_keys = [
            set(self.DataTables[foreign_name][pk_name].loc[~np.isnan(self.DataTables[foreign_name][pk_name])].tolist())
            for foreign_name in ref_tablenames if not self.DataTables[foreign_name] is None
        ]
        return reduce(flatten_sets, sets_of_keys or [], [])
