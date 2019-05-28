/* Select all tables that has no foreign_table_name that isn't in sead_table_dep_depths */

create or replace view clearing_house.view_sead_dependencies as
    with constraints as (
            select c.constraint_name
            , x.table_schema as schema_name
            , x.table_name
            , x.column_name
            , y.table_schema as foreign_schema_name
            , y.table_name as foreign_table_name
            , y.column_name as foreign_column_name
        from information_schema.referential_constraints c
        join information_schema.key_column_usage x
            on x.constraint_name = c.constraint_name
        join information_schema.key_column_usage y
            on y.ordinal_position = x.position_in_unique_constraint
            and y.constraint_name = c.unique_constraint_name
        order by c.constraint_name, x.ordinal_position
    ), dependencies as (
       select t.table_name, c.foreign_table_name
      from information_schema.tables t
      left join constraints c
        on c.schema_name = t.table_schema
       and c.table_name = t.table_name
       and c.foreign_schema_name =  t.table_schema
      where t.table_schema = 'public'
      --  and c.foreign_table_name is null
    ) select distinct table_name, foreign_table_name
      from dependencies;


Do $$
Declare
    v_rows_affected int default 0;
    v_depths int default 0;
    v_max_depths int default 10;
Begin

    drop table if exists clearing_house.sead_table_dep_depths;

    create table clearing_house.sead_table_dep_depths (
        table_name varchar(80) not null,
        depth int not null,
        Constraint pk_sead_table_dep_depths_table_name PRIMARY KEY (table_name)
    );

    Loop
        v_depths = v_depths + 1;
        insert into clearing_house.sead_table_dep_depths (table_name, depth)
            select t.table_name, v_depths
            from (
                Select d.table_name, count(d.foreign_table_name) as a_count, count(dd.table_name) as b_count, string_agg(d.foreign_table_name || case when dd.table_name  is null then '*' else '' end, ', ') as b_tables
                From clearing_house.view_sead_dependencies d
                Left Join clearing_house.sead_table_dep_depths dd
                  on dd.table_name = d.foreign_table_name
                where d.table_name <> coalesce(d.foreign_table_name, '')
                Group By d.table_name
            ) as t
            left join clearing_house.sead_table_dep_depths x
              on x.table_name = t.table_name
            Where 1 = 1
              and x.table_name is null
              and a_count = b_count;

        GET DIAGNOSTICS v_rows_affected = ROW_COUNT;

        Exit When v_rows_affected = 0;  -- same result as previous example
        Exit When v_depths = v_max_depths;
    End Loop;

End $$ language plpgsql;

with x as (
    Select d.table_name, count(d.foreign_table_name) as a_count, count(dd.table_name) as b_count, string_agg(d.foreign_table_name || case when dd.table_name  is null then '*' else '' end, ', ') as b_tables
    From clearing_house.view_sead_dependencies d
    Left Join clearing_house.sead_table_dep_depths dd
      on dd.table_name = d.foreign_table_name
    Group By d.table_name
) select *
  from x
  where a_count > b_count
