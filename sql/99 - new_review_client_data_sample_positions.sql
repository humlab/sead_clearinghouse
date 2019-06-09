-- drop function clearing_house.fn_clearinghouse_review_sample_positions_client_data(integer, integer);

create or replace function clearing_house.fn_clearinghouse_review_sample_positions(p_submission_id integer, p_physical_sample_id integer)
  returns table (

      local_db_id integer,
      sample_position text,
      position_accuracy character varying,
      method_name character varying,

      public_db_id integer,
      public_sample_position text,
      public_position_accuracy character varying,
      public_method_name character varying,

      entity_type_id integer
) as
$body$
declare
    entity_type_id int;
begin

    entity_type_id := clearing_house.fn_get_entity_type_for('tbl_sample_coordinates');

    return query

        select
            ldb.local_db_id				               	as local_db_id,
            coalesce(ldb.dimension_name, '') || ' ' ||
                coalesce(ldb.measurement, '')           as sample_position,
            ldb.accuracy                       		    as position_accuracy,
            ldb.method_name                       		as method_name,

            ldb.public_db_id				            as public_db_id,
            coalesce(rdb.dimension_name, '') || ' '||
                coalesce(rdb.measurement, '')           as public_sample_position,
            rdb.accuracy                       		    as public_position_accuracy,
            rdb.method_name                       		as public_method_name,
            rdb.dimension_name                       	as public_dimension_name,
            entity_type_id						        as entity_type_id
        from (

            select	ps.source_id						as source_id,
                    ps.submission_id					as submission_id,
                    ps.local_db_id						as physical_sample_id,
                    d.local_db_id						as local_db_id,
                    d.public_db_id						as public_db_id,
                    d.merged_db_id						as merged_db_id,
                    c.measurement::text 				as measurement,
                    c.accuracy						    as accuracy,
                    m.method_name						as method_name,
                    d.dimension_name::text				as dimension_name
            from clearing_house.view_physical_samples ps
            join clearing_house.view_sample_coordinates c
              on c.physical_sample_id = ps.merged_db_id
             and c.submission_id in (0, ps.submission_id)
            join clearing_house.view_coordinate_method_dimensions md
              on md.merged_db_id = c.coordinate_method_dimension_id
             and md.submission_id in (0, ps.submission_id)
            join clearing_house.view_methods m
              on m.merged_db_id = md.method_id
             and m.submission_id in (0, ps.submission_id)
            join clearing_house.view_dimensions d
              on d.merged_db_id = md.dimension_id
             and d.submission_id in (0, ps.submission_id)

        ) as ldb left join (

            select	c.sample_coordinate_id		as sample_coordinate_id,
                    c.measurement::text			as measurement,
                    c.accuracy					as accuracy,
                    m.method_name				as method_name,
                    d.dimension_name::text		as dimension_name
            from public.tbl_sample_coordinates c
            join public.tbl_coordinate_method_dimensions md
              on md.coordinate_method_dimension_id = c.coordinate_method_dimension_id
            join public.tbl_methods m
              on m.method_id = md.method_id
            join public.tbl_dimensions d
              on d.dimension_id = md.dimension_id

        ) as rdb
          on rdb.sample_coordinate_id = ldb.public_db_id
        where ldb.source_id = 1
          and ldb.submission_id = p_submission_id
          and ldb.physical_sample_id = -p_physical_sample_id;

end $body$
  language plpgsql;
