create schema if not exists flybase;
grant usage on schema flybase to PUBLIC;

/*
The flybase.get_feature_relationship functions take one or more feature.uniquename values,
a relationship type, a data class, and the direction of the feature you wish to fetch (subject/object).

If then returns a custom result of the corresponding feature_relationship columns and the ID and symbol of the 
target feature. 

Multiple relationship types and data classes can be specified by seperating them by pipe symbols
e.g.

-- Single IDs
select * from flybase.get_feature_relationship('FBgn0000490', 'associated_with|partof', 'FBti|FBtr');
select * from flybase.get_feature_relationship('FBgn0000490', 'alleleof', 'FBal');
select * from flybase.get_feature_relationship('FBgn0000490', 'alleleof', 'FBal', 'subject');
select * from flybase.get_feature_relationship('FBgn0000490', 'orthologous_to', 'FBgn|FBog');

-- Multiple IDs
select *
   from flybase.get_feature_relationship((select array_agg(f.uniquename) from feature f where uniquename in ('FBgn0000490','FBgn0013765')), 'alleleof', NULL,'subject')
;

If the data class is ommitted then all related feature rows are returned.
If the direction is ommitted then the subject direction is assumed.

If you want to pass a direction but omit the data class, use NULL for the data class value.

select * from flybase.get_feature_relationship('FBgn0000490', 'alleleof', NULL, 'subject');

*/
create or replace function flybase.get_feature_relationship(id text, relationship_type text, data_class text default '%', direction text default 'subject')
returns table(feature_relationship_id integer, object_id integer, subject_id integer, uniquename text, symbol varchar(255), rank integer, value text, type varchar(1024)) as $$
declare
  -- Cast scalar to an array.
  ids text[] = array_agg(id);
begin
  -- Call the main function with an array of a single ID.
  return query select * from flybase.get_feature_relationship(ids, relationship_type, data_class, direction);
end
$$ language plpgsql;
comment on function flybase.get_feature_relationship(text, text, text, text) is 'Given a feature.uniquename, relationship type, a FlyBase data class (default: all), and a chado feature_relationship direction (default: subject), fetches the corresponding relationships';

create or replace function flybase.get_feature_relationship(ids text[], relationship_type text, data_class text default '%', direction text default 'subject')
returns table(feature_relationship_id integer, object_id integer, subject_id integer, uniquename text, symbol varchar(255), rank integer, value text, type varchar(1024)) as $$
declare
  id text;
  feature1_linker text = 'object_id';
  feature2_linker text = 'subject_id';
  local_data_class text = data_class;
begin
  if data_class is NULL then
    local_data_class = '%';
  end if;

  -- Swap directions if we are looking in the object direction.
  if direction = 'object' then
    feature1_linker = 'subject_id';
    feature2_linker = 'object_id';
  end if;

  foreach id in array ids
  loop

    return query execute format('
      select fr.feature_relationship_id,
             fr.object_id,
             fr.subject_id,
             feature2.uniquename,
             flybase.current_symbol(feature2.uniquename),
             fr.rank,
             fr.value,
             cvt.name
        from feature feature1 join feature_relationship fr on feature1.feature_id = fr.%I
                              join feature feature2  on fr.%I = feature2.feature_id
                              join cvterm cvt on fr.type_id = cvt.cvterm_id
        where feature1.uniquename = %L
          and cvt.name similar to %L
          and flybase.data_class(feature2.uniquename) similar to %L
          and feature2.is_obsolete = false
      ', feature1_linker, feature2_linker, id, relationship_type, local_data_class)
    ;
  end loop;

  return;
end
$$
language plpgsql;
comment on function flybase.get_feature_relationship(text[], text, text, text) is 'Given an array of feature.uniquename, relationship type, a FlyBase data class (default: all), and a chado feature_relationship direction (default: subject), fetches the corresponding relationships';
