/*
* Potential update: table for all go_molecular_function terms, (or maybe just go terms)
* plus a relation table (this one) mapping genes to go terms?
*/
DROP TABLE IF EXISTS dataclass_relationship.gene_go_molecular_function CASCADE;

CREATE TABLE dataclass_relationship.gene_go_molecular_function
AS
SELECT DISTINCT gene.uniquename AS gene_id,
	CONCAT(db_gmf.name, ':', dbxr_gmf.accession) AS go_id,
	cvt_gmf."name" AS go_molecular_function,
	(
		fcvtp_gmf.value ~*
       'inferred from (physical interaction|direct assay|genetic interaction|mutant phenotype|expression pattern|(high throughput (experiment|direct assay|expression pattern|genetic interaction|mutant phenotype)))'
	) AS is_experimental
FROM feature gene
JOIN feature_cvterm fcvt_gmf
	ON (
		gene.feature_id = fcvt_gmf.feature_id
		AND fcvt_gmf.is_not = FALSE
	)
JOIN cvterm cvt_gmf
	ON (
		fcvt_gmf.cvterm_id = cvt_gmf.cvterm_id
		AND cvt_gmf.is_obsolete = 0
	)
JOIN cv cv_gmf
	ON (
		cvt_gmf.cv_id = cv_gmf.cv_id
		AND cv_gmf."name" = 'molecular_function'
	)
JOIN feature_cvtermprop fcvtp_gmf
	ON fcvt_gmf.feature_cvterm_id = fcvtp_gmf.feature_cvterm_id
JOIN cvterm cvt_fcvtp_gmf_type
	ON (
		fcvtp_gmf.type_id = cvt_fcvtp_gmf_type.cvterm_id
		AND cvt_fcvtp_gmf_type."name" = 'evidence_code'
	)
JOIN dbxref dbxr_gmf
	ON (
		cvt_gmf.dbxref_id = dbxr_gmf.dbxref_id
		AND dbxr_gmf.accession != '0005515'
	)
JOIN db db_gmf
	ON dbxr_gmf.db_id = db_gmf.db_id
WHERE gene.uniquename ~ '^FBgn[0-9]+$'
	AND gene.is_analysis = FALSE
	AND gene.is_obsolete = FALSE
;

ALTER TABLE dataclass_relationship.gene_go_molecular_function ADD PRIMARY KEY (gene_id, go_id, is_experimental);

ALTER TABLE dataclass_relationship.gene_go_molecular_function ADD CONSTRAINT gene_go_molecular_function_gene_id FOREIGN KEY (gene_id) REFERENCES dataclass.gene (id);

CREATE INDEX gene_go_molecular_function_idx1 ON dataclass_relationship.gene_go_molecular_function (gene_id);
CREATE INDEX gene_go_molecular_function_idx2 ON dataclass_relationship.gene_go_molecular_function (go_id);
CREATE INDEX gene_go_molecular_function_idx2 ON dataclass_relationship.gene_go_molecular_function (go_molecular_function);
CREATE INDEX gene_go_molecular_function_idx2 ON dataclass_relationship.gene_go_molecular_function (is_experimental);
