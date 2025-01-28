
DROP TABLE IF EXISTS dataclass_relationship.gene_disease CASCADE;

CREATE TABLE dataclass_relationship.gene_disease
AS
SELECT DISTINCT
	subquery.gene_id,
	subquery.disease_id,
	subquery.is_experimental,
	subquery.qualifier
FROM (
	SELECT
		CASE
			WHEN parent_gene.uniquename IS NOT NULL
				THEN parent_gene.uniquename
			WHEN gene_or_allele.uniquename ~ '^FBgn[0-9]+$'
				THEN gene_or_allele.uniquename
				ELSE null
		END AS gene_id,
		parent_gene.uniquename,
		gene_or_allele.uniquename AS gene_or_allele_id,
		db_gene."name" || ':' || dbxr_gene.accession AS disease_id,
	    fcvtp_gene.value ~ '\y(CEC|CEA)\y' AS is_experimental,
	    qualifier.value AS qualifier
	FROM feature gene_or_allele
	JOIN feature_cvterm fcvt_gene
		ON gene_or_allele.feature_id = fcvt_gene.feature_id
	JOIN cvterm cvt_gene
		ON fcvt_gene.cvterm_id = cvt_gene.cvterm_id
	JOIN cv cv_gene
		ON (
			cvt_gene.cv_id = cv_gene.cv_id
			AND cv_gene."name" = 'disease_ontology'
		)
	JOIN dbxref dbxr_gene
		ON cvt_gene.dbxref_id = dbxr_gene.dbxref_id
	JOIN db db_gene
		ON (
			dbxr_gene.db_id = db_gene.db_id
			AND db_gene."name" = 'DOID'
		)
	JOIN feature_cvtermprop fcvtp_gene
		ON (
			fcvt_gene.feature_cvterm_id = fcvtp_gene.feature_cvterm_id
			AND fcvtp_gene.value ~ '\y(CEC|CEA|IEA)\y'
		)
	JOIN cvterm cvt_fcvtp_gene_type
		ON (
			fcvtp_gene.type_id = cvt_fcvtp_gene_type.cvterm_id
			AND cvt_fcvtp_gene_type."name"  = 'evidence_code'
		)
	LEFT JOIN (
	    SELECT qual.feature_cvterm_id,
	    	qual.value
	    FROM feature_cvtermprop qual
	    JOIN cvterm qt ON qual.type_id = qt.cvterm_id
	    WHERE qt.name = 'qualifier'
	    	AND position('model of' IN qual.value) > 0
	) AS qualifier
		ON fcvt_gene.feature_cvterm_id = qualifier.feature_cvterm_id
	LEFT JOIN feature_relationship fr_gene_or_allele
		ON (
			gene_or_allele.feature_id = fr_gene_or_allele.subject_id
			AND gene_or_allele.uniquename ~ '^FBal[0-9]+$'
		)
	LEFT JOIN cvterm cvt_fr_gene_or_allele_type
		ON (
			fr_gene_or_allele.type_id = cvt_fr_gene_or_allele_type.cvterm_id
			AND cvt_fr_gene_or_allele_type."name" = 'alleleof'
		)
	LEFT JOIN feature parent_gene
		ON (
			fr_gene_or_allele.object_id = parent_gene.feature_id
			AND parent_gene.uniquename ~ '^FBgn[0-9]+$'
		)
	WHERE gene_or_allele.uniquename ~ '^FB(gn|al)[0-9]+$'
		AND gene_or_allele.is_analysis = FALSE
		AND gene_or_allele.is_obsolete = FALSE
) AS subquery
WHERE subquery.gene_id IS NOT NULL
;

ALTER TABLE dataclass_relationship.gene_disease ADD PRIMARY KEY (gene_id, disease_id, is_experimental, qualifier);

ALTER TABLE dataclass_relationship.gene_disease
    ADD CONSTRAINT gene_disease_fk1
    FOREIGN KEY (gene_id) REFERENCES dataclass.gene (id);
ALTER TABLE dataclass_relationship.gene_disease
    ADD CONSTRAINT gene_disease_fk2
    FOREIGN KEY (disease_id) REFERENCES dataclass.disease (id);

CREATE INDEX gene_disease_idx1 ON dataclass_relationship.gene_disease (gene_id);
CREATE INDEX gene_disease_idx2 ON dataclass_relationship.gene_disease (disease_id);
CREATE INDEX gene_disease_idx3 ON dataclass_relationship.gene_disease (is_experimental);
CREATE INDEX gene_disease_idx4 ON dataclass_relationship.gene_disease (qualifier);
