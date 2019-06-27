DROP TYPE IF EXISTS flybase.stock cascade;
CREATE TYPE flybase.stock AS (fbid text, fbst text, center text, stock_number text, genotype varchar(1024));

CREATE OR REPLACE FUNCTION flybase.get_stocks(id text)
RETURNS SETOF flybase.stock AS $$
DECLARE
  -- Cast scalar to an array.
  ids text[] = array_agg(id);
BEGIN
  -- Call the main function with an array of a single ID.
  RETURN QUERY SELECT * FROM flybase.get_stocks(ids);
END
$$ LANGUAGE plpgsql STABLE;
COMMENT ON FUNCTION flybase.get_stocks(text) IS 'Given a FlyBase ID, returns the associated stocks.';

CREATE OR REPLACE FUNCTION flybase.get_stocks(ids text[])
RETURNS SETOF flybase.stock AS $$
DECLARE
  id text;
  _r flybase.stock;
  num_genotype text[];
  id_genotype text[];
BEGIN
  FOREACH id IN ARRAY ids
  LOOP
    FOR _r IN
      SELECT f.uniquename as fbid,
             null as fbst,
             replace(fpt.name, 'derived_stock_', '') AS center,
             null as stock_number,
             regexp_split_to_table(fp.value, '\n') AS genotype
        FROM featureprop fp JOIN cvterm fpt ON (fp.type_id = fpt.cvterm_id)
                            JOIN feature f ON (fp.feature_id = f.feature_id)
        WHERE fpt.name ~ '^derived_stock_'
          AND f.uniquename = id
    LOOP
      SELECT regexp_split_to_array(_r.genotype, '\t') INTO num_genotype;
      _r.stock_number = num_genotype[1];
      SELECT regexp_split_to_array(trim(both ' @' from num_genotype[2]), ':') INTO id_genotype;
      _r.fbst     = id_genotype[1];
      _r.genotype = id_genotype[2];
      RETURN NEXT _r;
    END LOOP;
  END LOOP;

  RETURN;
END
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION flybase.get_stocks(text[]) IS 'Given an array of FlyBase IDs returns the associated stocks.';