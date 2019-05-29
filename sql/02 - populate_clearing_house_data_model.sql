/*********************************************************************************************************************************
**  Function    fn_dba_populate_clearing_house_db_model
**  When        2017-11-06
**  What        Adds data to DB clearing_house specific schema objects
**  Who         Roger Mähler
**  Note
**  Uses
**  Used By     Clearing House server installation. DBA.
**  Revisions
**********************************************************************************************************************************/
-- Select clearing_house.fn_dba_populate_clearing_house_db_model();
Create Or Replace Function clearing_house.fn_dba_populate_clearing_house_db_model() Returns void As $$
Begin

    If (Select Count(*) From clearing_house.tbl_clearinghouse_settings) = 0 Then

        Insert Into clearing_house.tbl_clearinghouse_settings (setting_group, setting_key, setting_value, setting_datatype)
            Values
                ('logger', 'folder', '/tmp/', 'string'),
                ('', 'max_execution_time', '120', 'numeric'),
                ('mailer', 'smtp-server', 'mail.acc.umu.se', 'string'),
                ('mailer', 'reply-address', 'noreply@sead.se', 'string'),
                ('mailer', 'sender-name', 'SEAD Clearing House', 'string'),
                ('mailer', 'smtp-auth', 'false', 'bool'),
                ('mailer', 'smtp-username', '', 'string'),
                ('mailer', 'smtp-password', '', 'string'),

                ('signal-templates', 'reject-subject', 'SEAD Clearing House: submission has been rejected', 'string'),
                ('signal-templates', 'reject-body',
'
Your submission to SEAD Clearing House has been rejected!

Reject causes:

#REJECT-CAUSES#

This is an auto-generated mail from the SEAD Clearing House system

', 'string'),

                ('signal-templates', 'reject-cause',
'

Entity type: #ENTITY-TYPE#
Error scope: #ERROR-SCOPE#
Entities: #ENTITY-ID-LIST#
Note:  #ERROR-DESCRIPTION#

--------------------------------------------------------------------

', 'string'),

                ('signal-templates', 'accept-subject', 'SEAD Clearing House: submission has been accepted', 'string'),

                ('signal-templates', 'accept-body',
'

Your submission to SEAD Clearing House has been accepted!

This is an auto-generated mail from the SEAD Clearing House system

', 'string'),

                ('signal-templates', 'reclaim-subject', 'SEAD Clearing House notfication: Submission #SUBMISSION-ID# has been transfered to pending', 'string'),

                ('signal-templates', 'reclaim-body', '

Status of submission #SUBMISSION-ID# has been reset to pending due to inactivity.

A submission is automatically reset to pending status when #DAYS-UNTIL-RECLAIM# days have passed since the submission
was claimed for review, and if no activity during has been registered during last #DAYS-WITHOUT-ACTIVITY# days.

This is an auto-generated mail from the SEAD Clearing House system.

', 'string'),

                ('signal-templates', 'reminder-subject', 'SEAD Clearing House reminder: Submission #SUBMISSION-ID#', 'string'),

                ('signal-templates', 'reminder-body', '

Status of submission #SUBMISSION-ID# has been reset to pending due to inactivity.

A reminder is automatically send when #DAYS-UNTIL-REMINDER# have passed since the submission
was claimed for review.

This is an auto-generated mail from the SEAD Clearing House system.

', 'string'),

                ('reminder', 'days_until_first_reminder', '14', 'numeric'),
                ('reminder', 'days_since_claimed_until_transfer_back_to_pending', '28', 'numeric'),
                ('reminder', 'days_without_activity_until_transfer_back_to_pending', '14', 'numeric');


    End If;

    insert into clearing_house.tbl_clearinghouse_info_references (info_reference_type, display_name, href)
        values
            ('link', 'SEAD overview article',  'http://bugscep.com/phil/publications/Buckland2010_jns.pdf'),
            ('link', 'Popular science description of SEAD aims',  'http://bugscep.com/phil/publications/buckland2011_international_innovation.pdf')
        on conflict do nothing;

    insert into clearing_house.tbl_clearinghouse_use_cases (use_case_id, use_case_name, entity_type_id)
        values  (0, 'General', 0),
                (1, 'Login', 1),
                (2, 'Logout', 1),
                (3, 'Upload submission', 2),
                (4, 'Accept submission', 2),
                (5, 'Reject submission', 2),
                (6, 'Open submission', 2),
                (7, 'Process submission', 2),
                (8, 'Transfer submission', 2),
                (9, 'Add reject cause', 2),
                (10, 'Delete reject cause', 2),
                (11, 'Claim submission', 2),
                (12, 'Unclaim submission', 2),
                (13, 'Execute report', 2),
                (20, 'Add user', 1),
                (21, 'Change user', 1),
                (22, 'Send reminder', 2),
                (23, 'Reclaim submission', 2),
                (24, 'Nag', 0)
        on conflict (use_case_id)
            do update
                set use_case_name = excluded.use_case_name,
                    entity_type_id = excluded.entity_type_id;

    insert into clearing_house.tbl_clearinghouse_data_provider_grades (grade_id, description)
        values (0, 'n/a'), (1, 'Normal'), (2, 'Good'), (3, 'Excellent')
        on conflict (grade_id)
            do update
                set description = excluded.description;

    insert into clearing_house.tbl_clearinghouse_user_roles (role_id, role_name)
        values (0, 'Undefined'),
                (1, 'Reader'),
                (2, 'Normal'),
                (3, 'Administrator'),
                (4, 'Data Provider')
        on conflict (role_id)
            do update
                set role_name = excluded.role_name;

    If (Select Count(*) From clearing_house.tbl_clearinghouse_users) = 0 Then
        Insert Into clearing_house.tbl_clearinghouse_users (user_name, password, full_name, role_id, data_provider_grade_id, create_date, email, signal_receiver)
            Values ('test_reader', '$2y$10$/u3RCeK8Q.2s75UsZmvQ4.4TOxvLNKH8EoH4k6NYYtkAMavjP.dry', 'Test Reader', 1, 0, '2013-10-08', 'roger.mahler@umu.se', false),
                   ('test_normal', '$2y$10$/u3RCeK8Q.2s75UsZmvQ4.4TOxvLNKH8EoH4k6NYYtkAMavjP.dry', 'Test Normal', 2, 0, '2013-10-08', 'roger.mahler@umu.se', false),
                   ('test_admin', '$2y$10$/u3RCeK8Q.2s75UsZmvQ4.4TOxvLNKH8EoH4k6NYYtkAMavjP.dry', 'Test Administrator', 3, 0, '2013-10-08', 'roger.mahler@umu.se', true),
                   ('test_provider', '$2y$10$/u3RCeK8Q.2s75UsZmvQ4.4TOxvLNKH8EoH4k6NYYtkAMavjP.dry', 'Test Provider', 3, 3, '2013-10-08', 'roger.mahler@umu.se', true),
                   ('phil_admin', '$2y$10$/u3RCeK8Q.2s75UsZmvQ4.4TOxvLNKH8EoH4k6NYYtkAMavjP.dry', 'Phil Buckland', 3, 3, '2013-10-08', 'phil.buckland@umu.se', true),
                   ('mattias_admin', '$2y$10$/u3RCeK8Q.2s75UsZmvQ4.4TOxvLNKH8EoH4k6NYYtkAMavjP.dry', 'Mattias Sjölander', 3, 3, '2013-10-08', 'mattias.sjolander@umu.se', true);
    End If;

    with sead_tables as (
        Select distinct table_name
        From clearing_house.fn_dba_get_sead_public_db_schema('public', 'sead_master')
    )
		insert into clearing_house.tbl_clearinghouse_submission_tables (table_name, table_name_underscored)
			select replace(initcap(replace(table_name, '_', ' ')), ' ', '') , table_name
			from sead_tables
			where table_name Like 'tbl_%'
        on conflict (table_name) do nothing;

    insert into clearing_house.tbl_clearinghouse_submission_states (submission_state_id, submission_state_name)
        values	(0, 'Undefined'),
                (1, 'New'),
                (2, 'Pending'),
                (3, 'In progress'),
                (4, 'Accepted'),
                (5, 'Rejected'),
                (9, 'Error')
        on conflict (submission_state_id)
            do update
                set submission_state_name = excluded.submission_state_name;

    If (Select Count(*) From clearing_house.tbl_clearinghouse_reject_entity_types) = 0 Then

		--Delete From clearing_house.tbl_clearinghouse_reject_entity_types
        Insert Into clearing_house.tbl_clearinghouse_reject_entity_types (entity_type_id, table_id, entity_type)

            Select 0,  0, 'Not specified'
			Union
            Select row_number() over (ORDER BY table_name),  table_id, left(substring(table_name,4),Length(table_name)-4)
            From clearing_house.tbl_clearinghouse_submission_tables
            Where table_name Like 'Tbl%s'
            Order by 1;

        /* Komplettera med nya */
        Insert Into clearing_house.tbl_clearinghouse_reject_entity_types (entity_type_id, table_id, entity_type)

            Select (Select Max(entity_type_id) From clearing_house.tbl_clearinghouse_reject_entity_types) + row_number() over (ORDER BY table_name),  t.table_id, left(substring(table_name,4),Length(table_name)-3)
            From clearing_house.tbl_clearinghouse_submission_tables t
			Left Join clearing_house.tbl_clearinghouse_reject_entity_types x
			  On x.table_id = t.table_id
            Where x.table_id Is Null
            Order by 1;


        /* Fixa beskrivningstext */
        Update clearing_house.tbl_clearinghouse_reject_entity_types as x
			set entity_type = replace(trim(replace(regexp_replace(t.table_name, E'([A-Z])', E'\_\\1','g'), '_', ' ')), 'Tbl ', '')
        From clearing_house.tbl_clearinghouse_submission_tables t
        Where t.table_id = x.table_id
          And replace(trim(replace(regexp_replace(t.table_name, E'([A-Z])', E'\_\\1','g'), '_', ' ')), 'Tbl ', '') <> x.entity_type;

    End If;

    insert into clearing_house.tbl_clearinghouse_reports (report_id, report_name, report_procedure)
        values  ( 1, 'Locations', 'Select * From clearing_house.fn_clearinghouse_report_locations(?)'),
                ( 2, 'Bibliography entries', 'Select * From clearing_house.fn_clearinghouse_report_bibliographic_entries(?)'),
                ( 3, 'Data sets', 'Select * From clearing_house.fn_clearinghouse_report_datasets(?)'),
                ( 4, 'Ecological reference data - Taxonomic order', 'Select * From clearing_house.fn_clearinghouse_report_taxonomic_order(?)'),
                ( 5, 'Taxonomic tree (master)', 'Select * From clearing_house.fn_clearinghouse_report_taxa_tree_master(?)'),
                ( 6, 'Ecological reference data - Taxonomic tree (other)', 'Select * From clearing_house.fn_clearinghouse_report_taxa_other_lists(?)'),
                ( 7, 'Ecological reference data - Taxonomic RGB codes', 'Select * From clearing_house.fn_clearinghouse_report_taxa_rdb(?)'),
                ( 8, 'Ecological reference data - Taxonomic eco-codes', 'Select * From clearing_house.fn_clearinghouse_report_taxa_ecocodes(?)'),
                ( 9, 'Ecological reference data - Taxonomic seasonanlity', 'Select * From clearing_house.fn_clearinghouse_report_taxa_seasonality(?)'),
                (11, 'Relative ages', 'Select * From clearing_house.fn_clearinghouse_report_relative_ages(?)'),
                (12, 'Methods', 'Select * From clearing_house.fn_clearinghouse_report_methods(?)'),
                (13, 'Feature types', 'Select * From clearing_house.fn_clearinghouse_report_feature_types(?)'),
                (14, 'Sample group descriptions', 'Select * From clearing_house.fn_clearinghouse_report_sample_group_descriptions(?)'),
                (15, 'Sample group dimensions', 'Select * From clearing_house.fn_clearinghouse_report_sample_group_dimensions(?)'),
                (16, 'Sample dimensions', 'Select * From clearing_house.fn_clearinghouse_report_sample_dimensions(?)'),
                (17, 'Sample descriptions', 'Select * From clearing_house.fn_clearinghouse_report_sample_descriptions(?)'),
                (18, 'Ceramic values', 'Select * From clearing_house.fn_clearinghouse_review_ceramic_values_crosstab(?)')
    on conflict (report_id)
        do update
            set report_name = excluded.report_name,
                report_procedure = excluded.report_procedure;

end $$ language plpgsql;
