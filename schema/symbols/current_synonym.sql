create schema if not exists flybase;
grant usage on schema flybase to PUBLIC;

-- Function to fetch a current entry from the synonym table using the 
-- specified FlyBase ID and the type (symbol, fullname, etc.).
-- Returns a single value or null.
create or replace function flybase.current_synonym(id text, synonym_type text)
returns varchar(255) as $$
declare
  -- The synonym.synonym_sgml value to return.
  synonym varchar(255);
  -- Variables to vary which tables and fields we are using to resolve the synonyms.
  linker_table text = 'feature_synonym';
  object_table text = 'feature';
  linker_field text = 'feature_id';
begin
  -- Switch tables and fields based on data class.
  if upper(flybase.data_class(id)) = 'FBGG' then
    linker_table = 'grp_synonym';
    object_table = 'grp';
    linker_field = 'grp_id';
  elsif upper(flybase.data_class(id)) = 'FBSN' then
    linker_table = 'strain_synonym';
    object_table = 'strain';
    linker_field = 'strain_id';
  elsif upper(flybase.data_class(id)) = 'FBTC' then
    linker_table = 'cell_line_synonym';
    object_table = 'cell_line';
    linker_field = 'cell_line_id';
  elsif upper(flybase.data_class(id)) = 'FBHH' then
    linker_table = 'humanhealth_synonym';
    object_table = 'humanhealth';
    linker_field = 'humanhealth_id';
  elsif upper(flybase.data_class(id)) = 'FBLC' then
    linker_table = 'library_synonym';
    object_table = 'library';
    linker_field = 'library_id';
  end if;

  -- Execute the query using the PostgreSQL format() function to substitute the various
  -- table and field names.  Store result in the synonym variable.
  execute format('
    select s.synonym_sgml
      from %1$I obj join %2$I linker on obj.%3$I = linker.%3$I
                      join synonym s on linker.synonym_id = s.synonym_id
                      join cvterm cvt on s.type_id=cvt.cvterm_id
      where obj.uniquename = %4$L
        and linker.is_current = true and linker.is_internal = false
        and cvt.name = %5$L 
    limit 1;', object_table, linker_table, linker_field, id, synonym_type)
  into synonym;

  -- Return the synonym.
  return synonym;
end
$$ language plpgsql;
comment on function flybase.current_synonym(text, text) is 'Given a feature.uniquename and a synonym type, it retrieves a single synonym that is the current value of the type or null.';

-- Function to fetch the current symbol
create or replace function flybase.current_symbol(id text)
returns varchar(255) as $$
declare
  field text = 'symbol';
begin
  return flybase.current_synonym(id, field);
end
$$ language plpgsql;
comment on function flybase.current_symbol(text) is 'Given a feature.uniquename, this function returns a single current symbol or null if none exists.';

-- Function to fetch the current fullname.
create or replace function flybase.current_fullname(id text)
returns varchar(255) as $$
declare
  field text = 'fullname';
begin
  return flybase.current_synonym(id, field);
end
$$ language plpgsql;
comment on function flybase.current_fullname(text) is 'Given a feature.uniquename, this function returns a single current fullname or null if none exists.';
