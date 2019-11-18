CREATE SCHEMA IF NOT EXISTS flybase;
GRANT USAGE ON SCHEMA flybase TO PUBLIC;

CREATE OR REPLACE FUNCTION flybase.get_featureprop(id text, type text)
    RETURNS SETOF featureprop AS
$$
SELECT fp.*
FROM feature f
         JOIN featureprop fp ON f.feature_id = fp.feature_id
         JOIN cvterm cvt ON fp.type_id = cvt.cvterm_id
WHERE f.uniquename = $1
  AND f.is_obsolete = false
  AND cvt.name SIMILAR TO $2
  AND cvt.is_obsolete = 0
    ;
$$ LANGUAGE SQL STABLE;

CREATE OR REPLACE FUNCTION flybase.get_pubprop(id text, type text)
    RETURNS SETOF pubprop AS
$$
SELECT pp.*
FROM pub p
         JOIN pubprop pp ON pp.pub_id = p.pub_id
         JOIN cvterm cvt ON pp.type_id = cvt.cvterm_id
WHERE p.uniquename = $1
  AND p.is_obsolete = false
  AND cvt.name SIMILAR TO $2
  AND cvt.is_obsolete = 0
    ;
$$ LANGUAGE SQL STABLE;

