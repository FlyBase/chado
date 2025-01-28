
DROP TABLE IF EXISTS dataclass_relationship.gene_enzyme CASCADE;

CREATE TABLE dataclass_relationship.gene_enzyme
AS
SELECT DISTINCT
	gene.uniquename AS gene_id,
	enzyme.accession AS enzyme_id
FROM feature gene
JOIN feature_cvterm fcvt_gene
	USING (feature_id)
JOIN cvterm cvt_gene
	USING (cvterm_id)
JOIN cvterm_dbxref cvt_dbxr_gene
	ON cvt_gene.cvterm_id = cvt_dbxr_gene.cvterm_id
JOIN dbxref enzyme
	ON cvt_dbxr_gene.dbxref_id = enzyme.dbxref_id
JOIN dbxrefprop dbxrp_enzyme
	ON enzyme.dbxref_id = dbxrp_enzyme.dbxref_id
JOIN cvterm cvt_dbxrp_enzyme_type
	ON (
		dbxrp_enzyme.type_id = cvt_dbxrp_enzyme_type.cvterm_id
		AND cvt_dbxrp_enzyme_type."name" = 'ec_description'
	)
WHERE gene.uniquename ~ '^FBgn[0-9]+$'
	AND gene.is_analysis = FALSE
	AND gene.is_obsolete = FALSE
;

ALTER TABLE dataclass_relationship.gene_enzyme ADD PRIMARY KEY (gene_id, enzyme_id);

ALTER TABLE dataclass_relationship.gene_enzyme
    ADD CONSTRAINT gene_enzyme_fk1
    FOREIGN KEY (gene_id) REFERENCES dataclass.gene (id);
ALTER TABLE dataclass_relationship.gene_enzyme
    ADD CONSTRAINT gene_enzyme_fk2
    FOREIGN KEY (enzyme_id) REFERENCES dataclass.enzyme (id);

CREATE INDEX gene_enzyme_idx1 ON dataclass_relationship.gene_enzyme (gene_id);
CREATE INDEX gene_enzyme_idx2 ON dataclass_relationship.gene_enzyme (enzyme_id);
