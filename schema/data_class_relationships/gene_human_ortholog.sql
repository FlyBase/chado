
DROP TABLE IF EXISTS dataclass_relationship.gene_human_ortholog CASCADE;

CREATE TABLE dataclass_relationship.gene_human_ortholog
AS
SELECT gene.uniquename AS gene_id,
	ortholog.uniquename AS ortholog_id,
	gene_ortholog_feature_relationship.diopt_score,
	dbxr_ortholog.description AS "name",
    dbxr_ortholog.accession,
	db_ortholog.urlprefix || dbxr_ortholog.accession AS "url"
FROM feature gene
-- Add feature_relationship with diopt score
JOIN (
	SELECT fr.*,
	cardinality(
		string_to_array(
			regexp_match(fr.value, '(?<=^diopt\smethods:\s)([^\n]+)')::text,
			', '
		)
	) AS diopt_score
	FROM feature_relationship fr
	WHERE position('diopt methods' IN fr.value) > 0
) AS gene_ortholog_feature_relationship
	ON gene.feature_id = gene_ortholog_feature_relationship.object_id
JOIN cvterm cvt_gene_human_ortholog_relationship_type
	ON (
		gene_ortholog_feature_relationship.type_id = cvt_gene_human_ortholog_relationship_type.cvterm_id
		AND cvt_gene_human_ortholog_relationship_type."name" = 'orthologous_to'
	)
--Add ortholog
JOIN feature ortholog
	ON (
		ortholog.organism_id = 226 --Human
	    AND gene_ortholog_feature_relationship.subject_id = ortholog.feature_id
		AND ortholog.uniquename ~ '^FBog[0-9]+$'
		AND ortholog.is_analysis = FALSE
		AND ortholog.is_obsolete = FALSE
	)
JOIN feature_dbxref fdbxf_ortholog
    ON (
        ortholog.feature_id = fdbxf_ortholog.feature_id
        AND fdbxf_ortholog.is_current = TRUE
    )
JOIN dbxref dbxr_ortholog
	ON fdbxf_ortholog.dbxref_id = dbxr_ortholog.dbxref_id
JOIN db db_ortholog
	ON (
		dbxr_ortholog.db_id = db_ortholog.db_id
		AND db_ortholog."name" = 'HGNC'
	)
WHERE gene.uniquename ~ '^FBgn[0-9]+$'
	AND gene.is_analysis = FALSE
	AND gene.is_obsolete = FALSE
;

ALTER TABLE dataclass_relationship.gene_human_ortholog ADD PRIMARY KEY (gene_id, ortholog_id);

ALTER TABLE dataclass_relationship.gene_human_ortholog ADD CONSTRAINT gene_go_molecular_function_gene_id FOREIGN KEY (gene_id) REFERENCES dataclass.gene (id);
ALTER TABLE dataclass_relationship.gene_human_ortholog ADD CONSTRAINT gene_go_molecular_function_ortholog_id FOREIGN KEY (ortholog_id) REFERENCES dataclass.ortholog (id);

CREATE INDEX gene_gene_human_ortholog_idx1 ON dataclass_relationship.gene_human_ortholog (gene_id);
CREATE INDEX gene_gene_human_ortholog_idx2 ON dataclass_relationship.gene_human_ortholog (ortholog_id);
CREATE INDEX gene_gene_human_ortholog_idx3 ON dataclass_relationship.gene_human_ortholog (diopt_score);
CREATE INDEX gene_gene_human_ortholog_idx4 ON dataclass_relationship.gene_human_ortholog ("name");
CREATE INDEX gene_gene_human_ortholog_idx5 ON dataclass_relationship.gene_human_ortholog (accession);
CREATE INDEX gene_gene_human_ortholog_idx6 ON dataclass_relationship.gene_human_ortholog ("url");
