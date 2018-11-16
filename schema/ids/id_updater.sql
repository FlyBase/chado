create schema if not exists flybase;
grant usage on schema flybase to PUBLIC;

-- Enum type for ID update status.
drop type if exists flybase.update_status cascade;
create type flybase.update_status as enum ('current','updated','split');

-- Custom type for result of ID update.
drop type if exists flybase.updated_id cascade;
create type flybase.updated_id as (
  submitted_id  text,
  updated_id  text,
  status flybase.update_status
);

create or replace function flybase.update_ids (id text) returns setof flybase.updated_id as $$
declare
updated_id    flybase.updated_id%rowtype;
secondary_ids flybase.updated_id[];
result_row    flybase.updated_id%rowtype;
num_rows      integer = 0;
found_id      boolean = false;
begin
  -- Check if it is a current ID.
  select id, f.uniquename, 'current'
    into updated_id
    from feature f
    where f.uniquename  = id
      and f.is_obsolete = false;

  if FOUND then
    found_id = true;
    return next updated_id; 
  end if;

  -- Check for a secondary ID due to a merge or a split.
  secondary_ids = array(
    select row(id, f.uniquename, 'updated')
      from feature f join feature_dbxref fdbx on (f.feature_id=fdbx.feature_id)
                     join dbxref dbx on (fdbx.dbxref_id=dbx.dbxref_id)
                     join db on (dbx.db_id=db.db_id)
      where fdbx.is_current=false
        and dbx.accession=id
        and lower(db.name) = 'flybase'
        and f.is_obsolete = false);

  num_rows = array_length(secondary_ids,1);

  if num_rows > 0 then 
    found_id = true;
    for result_row in select * from unnest(secondary_ids)
    loop
      -- If more than one row is found it is due to a split.
      if num_rows > 1 then
        result_row.status = 'split';
      end if;
      return next result_row;
    end loop;
  end if;

  if not found_id then
    return next (id,null,null)::flybase.updated_id;
  end if;
  return;
end
$$ language plpgsql;

comment on function flybase.update_ids(text) is 'Accepts a single FlyBase ID and tries to validate and update it based on the current database.  Returns a 3 column result set of the submitted ID, updated ID, and conversion status.';

-- Function to operate on a list of IDs.
create or replace function flybase.update_ids (ids text[]) returns setof flybase.updated_id as $$
declare
id text;
begin
  foreach id in array ids loop 
    return query select * from flybase.update_ids(id);
  end loop;
  return;
end
$$ language plpgsql;

comment on function flybase.update_ids(text[]) is 'Accepts an array of FlyBase IDs and tries to validate and update it based on the current database.  Returns a 3 column result set of the submitted ID, updated ID, and conversion status.'