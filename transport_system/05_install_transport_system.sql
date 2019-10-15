
set client_min_messages to warning;

\i '01_setup_transport_schema.psql'
\i '02_resolve_primary_keys.psql'
\i '03_resolve_foreign_keys.psql'
\i '04_script_data_transport.psql'

do $$
begin
    perform clearing_house_commit.generate_sead_tables();
    perform clearing_house_commit.generate_resolve_functions('public', false);
end $$ language plpgsql;
