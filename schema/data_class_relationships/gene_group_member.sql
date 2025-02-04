
DROP TABLE IF EXISTS dataclass_relationship.gene_group_member CASCADE;

CREATE TABLE dataclass_relationship.gene_group_member
AS
SELECT
	gene.uniquename AS gene_id,
	grp.uniquename AS gene_group_id,
	SUBSTRING(gmp.value FROM '(?<=^@)FBgg\d{7}(?=:)') AS subgroup_id,
	gmp.value AS group_member_label,
	JSONB_AGG(DISTINCT pub.uniquename) AS gene_group_pubs
FROM feature gene
JOIN feature_grpmember fgm
	USING (feature_id)
JOIN grpmember gm
	USING (grpmember_id)
JOIN grp
	USING (grp_id)
JOIN cvterm cvt_gm_type
	ON cvt_gm_type.cvterm_id = gm.type_id
LEFT JOIN grpmemberprop gmp
	USING (grpmember_id)
LEFT JOIN cvterm cvt_gmp_type
	ON (
		cvt_gmp_type.cvterm_id = gmp.type_id
		AND cvt_gmp_type."name" = 'derived_grpmember_label'
	)
	JOIN grp_cvterm gcvt_type
	ON grp.grp_id = gcvt_type.grp_id
JOIN cvterm cvt_type
	ON gcvt_type.cvterm_id = cvt_type.cvterm_id
JOIN dbxref dbxr_type
	ON cvt_type.dbxref_id = dbxr_type.dbxref_id
LEFT JOIN feature_grpmember_pub fgmp
	ON fgmp.feature_grpmember_id = fgm.feature_grpmember_id
LEFT JOIN pub
	ON (
		fgmp.feature_grpmember_pub_id = pub.pub_id
		AND pub.is_obsolete = FALSE
		AND pub.uniquename ~ '^FBrf[0-9]+$'
	)
LEFT JOIN cvterm cvt_pub_type
	ON (
		pub.type_id = cvt_pub_type.cvterm_id
		AND cvt_pub_type."name" = 'paper'
	)
WHERE gene.uniquename ~ '^FBgn[0-9]+$'
	AND gene.is_analysis = FALSE
	AND gene.is_obsolete = FALSE
GROUP BY gene.uniquename, grp.uniquename, gmp.value
;


ALTER TABLE dataclass_relationship.gene_group_member ALTER COLUMN subgroup_id DROP NOT NULL;

ALTER TABLE dataclass_relationship.gene_group_member ADD PRIMARY KEY (gene_id, gene_group_id, subgroup_id);

ALTER TABLE dataclass_relationship.gene_group_member
    ADD CONSTRAINT gene_group_member_fk1
    FOREIGN KEY (gene_id) REFERENCES dataclass.gene (id);
ALTER TABLE dataclass_relationship.gene_group_member
    ADD CONSTRAINT gene_group_member_fk2
    FOREIGN KEY (gene_group_id) REFERENCES dataclass.gene_group (id);
ALTER TABLE dataclass_relationship.gene_group_member
    ADD CONSTRAINT gene_group_member_fk3
    FOREIGN KEY (subgroup_id) REFERENCES dataclass.gene_group (id);


CREATE INDEX gene_group_member_idx1 ON dataclass_relationship.gene_group_member (gene_id);
CREATE INDEX gene_group_member_idx2 ON dataclass_relationship.gene_group_member (gene_group_id);
CREATE INDEX gene_group_member_idx3 ON dataclass_relationship.gene_group_member (subgroup_id);
CREATE INDEX gene_group_member_idx4 ON dataclass_relationship.gene_group_member (group_member_label);
