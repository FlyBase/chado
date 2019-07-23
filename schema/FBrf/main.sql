CREATE SCHEMA IF NOT EXISTS flybase;


/**
This function takes a FlyBase ID and returns a count of publications
for that object.  It only counts direct publication associations between
the main table of the FlyBase object and a pub (e.g. feature -> feature_pub -> pub).

*/
CREATE OR REPLACE FUNCTION flybase.pub_count(id text)
RETURNS bigint AS $$
DECLARE
  count bigint = 0;
  -- Variables to vary which tables and fields we are using to resolve the synonyms.
  linker_table text;
  object_table text;
  linker_field text;
BEGIN
  -- Switch tables and fields based on data class.
  CASE upper(flybase.data_class(id))
    WHEN 'FBGG' THEN
      linker_table = 'grp_pub';
      object_table = 'grp';
      linker_field = 'grp_id';
    WHEN 'FBSN' THEN
      linker_table = 'strain_pub';
      object_table = 'strain';
      linker_field = 'strain_id';
    WHEN 'FBTC' THEN
      linker_table = 'cell_line_pub';
      object_table = 'cell_line';
      linker_field = 'cell_line_id';
    WHEN 'FBHH' THEN
      linker_table = 'humanhealth_pub';
      object_table = 'humanhealth';
      linker_field = 'humanhealth_id';
    WHEN 'FBLC' THEN
      linker_table = 'library_pub';
      object_table = 'library';
      linker_field = 'library_id';
    ELSE
      linker_table = 'feature_pub';
      object_table = 'feature';
      linker_field = 'feature_id';
  END CASE;

  -- Execute the query using the PostgreSQL format() function to substitute the various
  -- table and field names.
  EXECUTE format('
    select count(p.*)
      from %1$I obj join %2$I linker on obj.%3$I = linker.%3$I
                      join pub p on linker.pub_id = p.pub_id
      where obj.uniquename = %4$L
        and obj.is_obsolete = false
        and p.is_obsolete = false
        and upper(flybase.data_class(p.uniquename)) = %5$L
    ;', object_table, linker_table, linker_field, id, 'FBRF')
    INTO count;
    RETURN count;
END
$$ LANGUAGE plpgsql stable;
COMMENT ON FUNCTION flybase.pub_count(text) IS 'Given a FlyBase ID, returns a count of FlyBase pub records directly associated with it.';
