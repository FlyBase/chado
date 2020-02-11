CREATE SCHEMA IF NOT EXISTS flybase;
GRANT USAGE ON SCHEMA flybase TO PUBLIC;

CREATE OR REPLACE FUNCTION flybase.is_go_evidence_experimental(evidence_code text)
    RETURNS BOOLEAN AS
$$
SELECT evidence_code ~*
       'inferred from (physical interaction|direct assay|genetic interaction|mutant phenotype|expression pattern|(high throughput (experiment|direct assay|expression pattern|genetic interaction|mutant phenotype)))';
$$ LANGUAGE SQL STABLE;

COMMENT ON FUNCTION flybase.is_go_evidence_experimental(TEXT) IS 'Given a Gene Ontology evidence code, returns whether or not it is experimental (true) or prediction (false).';

CREATE OR REPLACE FUNCTION flybase.get_gene_ontology_terms(id text, go_aspect text)
    RETURNS SETOF feature_cvterm AS
$$
SELECT fcvt.*
FROM feature g
         JOIN feature_cvterm fcvt ON g.feature_id = fcvt.feature_id
         JOIN cvterm cvt ON fcvt.cvterm_id = cvt.cvterm_id
         JOIN cv ON cvt.cv_id = cv.cv_id
WHERE cv.name = go_aspect
  AND cvt.is_obsolete::boolean = false
  AND g.uniquename = id
    ;
$$ LANGUAGE SQL STABLE;
