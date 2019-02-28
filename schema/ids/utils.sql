create schema if not exists flybase;
grant usage on schema flybase to PUBLIC;

-- Given a FlyBase ID, returns the 4 letter FlyBase data class.
create or replace function flybase.data_class(id text)
returns text as $$
declare
  -- Data class to return.
  data_class text;
begin
  -- Get the substring.
  data_class = substring(id from 1 for 4);
  -- Format and return it.
  return upper(substring(data_class from 1 for 2)) || lower(substring(data_class from 3 for 2));
end
$$ language plpgsql;
comment on function flybase.data_class(text) is 'Given a FlyBase ID returns the data class prefix e.g. FBgn0000490 -> FBgn';