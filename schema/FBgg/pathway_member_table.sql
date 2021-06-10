CREATE SCHEMA IF NOT EXISTS gene_group;

DROP TABLE IF EXISTS gene_group.pathway_member CASCADE;

/**
  A table to track all genes that are a member of the pathway.
 */
CREATE TABLE gene_group.pathway_member
AS
SELECT DISTINCT ON (fbgg_id, fbgn_id, prop.value) pathway.uniquename                        AS fbgg_id,
                                                  fbgn.uniquename                           AS fbgn_id,
                                                  flybase.current_symbol(fbgn.uniquename)   AS symbol,
                                                  flybase.current_fullname(fbgn.uniquename) AS name,
                                                  prop.value                                AS group_member_label,
                                                  (SELECT jsonb_agg(distinct p.uniquename)
                                                   FROM feature_grpmember_pub fgp
                                                            JOIN pub p ON fgp.pub_id = p.pub_id
                                                            JOIN cvterm type ON p.type_id = type.cvterm_id
                                                   WHERE flybase.data_class(p.uniquename) = 'FBrf'
                                                     AND p.is_obsolete = false
                                                     AND fgp.feature_grpmember_id = fgrpm.feature_grpmember_id
                                                     AND type.name = 'paper'
                                                  )                                         AS pathway_pubs
FROM gene_group.pathway AS pathway
         JOIN grpmember grpm ON pathway.grp_id = grpm.grp_id
         JOIN feature_grpmember fgrpm ON grpm.grpmember_id = fgrpm.grpmember_id
         JOIN feature fbgn ON fgrpm.feature_id = fbgn.feature_id
         LEFT JOIN flybase.get_grpmemberprop(grpm.grpmember_id, 'derived_grpmember_label') prop
                   ON (grpm.grpmember_id = prop.grpmember_id)
;

CREATE OR REPLACE FUNCTION gene_group.gene_group_members(fbgg text, subgroup text)
    RETURNS SETOF gene_group.pathway_member AS
$$
SELECT ggpm.*
FROM gene_group.pathway_member AS ggpm
WHERE ggpm.fbgg_id = fbgg
  AND (
        (NULLIF(subgroup, '') IS NULL AND ggpm.group_member_label IS NULL)
        OR
        position('@' || UPPER(subgroup) || ':' in UPPER(ggpm.group_member_label)) > 0
    )
    ;
$$ LANGUAGE SQL STABLE;

ALTER TABLE gene_group.pathway_member
    ADD COLUMN aka text DEFAULT NULL;
UPDATE gene_group.pathway_member
SET aka = (SELECT string_agg(value, ', ') FROM flybase.get_featureprop(fbgn_id, 'derived_aka_synonyms'));

ALTER TABLE gene_group.pathway_member
    ADD COLUMN antibody boolean DEFAULT false;
-- Check for curated antibody information or commercially available options.
UPDATE gene_group.pathway_member
SET antibody = (
    SELECT (
                   (SELECT COUNT(*) != 0 FROM flybase.get_featureprop(fbgn_id, 'reported_antibod_gen'))
                   OR
                   (EXISTS(SELECT 1
                           FROM feature f
                                    JOIN feature_dbxref fdbx on f.feature_id = fdbx.feature_id
                                    JOIN dbxref dbx on fdbx.dbxref_id = dbx.dbxref_id
                                    JOIN db on dbx.db_id = db.db_id
                           WHERE f.uniquename = fbgn_id
                             AND f.is_obsolete = false
                             AND f.is_analysis = false
                             AND fdbx.is_current = true
                             AND upper(db.name) in ('DSHB', 'CST')
                       ))
               ));

ALTER TABLE gene_group.pathway_member
    ADD COLUMN pubs jsonb DEFAULT NULL;

UPDATE gene_group.pathway_member
SET pubs =
        (SELECT jsonb_agg(distinct p.uniquename)
         FROM feature f
                  JOIN feature_pub fp ON f.feature_id = fp.feature_id
                  JOIN pub p ON fp.pub_id = p.pub_id
                  JOIN cvterm type ON p.type_id = type.cvterm_id
         WHERE flybase.data_class(p.uniquename) = 'FBrf'
           AND p.is_obsolete = false
           AND f.uniquename = fbgn_id
           AND type.name = 'paper'
        );

ALTER TABLE gene_group.pathway_member
    ADD COLUMN classical_alleles jsonb DEFAULT NULL;

UPDATE gene_group.pathway_member
SET classical_alleles =
        (SELECT json_agg(
                        jsonb_build_object(
                                'id',
                                fbal.fbal_id,
                                'symbol',
                                fbal.symbol
                            )
                    )
         FROM gene.gene fbgn
                  JOIN gene.allele fbal ON fbgn.feature_id = fbal.gene_id
         WHERE fbal.is_construct = false
           AND fbgn.uniquename = fbgn_id
        );

ALTER TABLE gene_group.pathway_member
    ADD COLUMN constructs jsonb DEFAULT NULL;

UPDATE gene_group.pathway_member
SET constructs =
        (SELECT json_agg(
                        jsonb_build_object(
                                'id',
                                fbal.fbal_id,
                                'symbol',
                                fbal.symbol
                            )
                    )
         FROM gene.gene fbgn
                  JOIN gene.allele fbal ON fbgn.feature_id = fbal.gene_id
         WHERE fbal.is_construct = true
           AND fbgn.uniquename = fbgn_id
        );

ALTER TABLE gene_group.pathway_member
    ADD COLUMN go_molecular_function jsonb DEFAULT NULL;

UPDATE gene_group.pathway_member
SET go_molecular_function =
        (SELECT json_agg(DISTINCT
                         jsonb_build_object(
                                 'id',
                                 db.name || ':' || dbx.accession,
                                 'name',
                                 cvt.name
                             )
                    )
         FROM feature g
                  JOIN flybase.get_gene_ontology_terms(g.uniquename, 'molecular_function') GO
                       ON g.feature_id = GO.feature_id
                  JOIN feature_cvtermprop fcvtp ON GO.feature_cvterm_id = fcvtp.feature_cvterm_id
                  JOIN cvterm cvt ON GO.cvterm_id = cvt.cvterm_id
                  JOIN cvterm fcvtpt ON fcvtp.type_id = fcvtpt.cvterm_id
                  JOIN cv ON cvt.cv_id = cv.cv_id
                  JOIN dbxref dbx ON cvt.dbxref_id = dbx.dbxref_id
                  JOIN db ON dbx.db_id = db.db_id
         WHERE g.uniquename = fbgn_id
           AND fcvtpt.name = 'evidence_code'
           AND flybase.is_go_evidence_experimental(fcvtp.value) = true -- Only terms based on experimental evidence
           AND GO.is_not = false                                       -- exclude negated terms
           AND dbx.accession != '0005515' -- exclude protein_binding
        );

ALTER TABLE gene_group.pathway_member
    ADD COLUMN human_orthologs jsonb DEFAULT NULL;

UPDATE gene_group.pathway_member
SET human_orthologs =
        (SELECT json_agg(
                        jsonb_build_object(
                                'id',
                                dbx.accession,
                                'symbol',
                                flybase.current_symbol(f.uniquename),
                                'name',
                                dbx.description,
                                'url',
                                db.urlprefix || dbx.accession
                            )
                    )
         FROM flybase.get_feature_relationship(fbgn_id, 'orthologous_to', 'FBgn|FBog', 'subject') fr
                  JOIN feature f ON fr.subject_id = f.feature_id
                  JOIN organism o ON f.organism_id = o.organism_id
                  JOIN feature_dbxref fdbx ON f.feature_id = fdbx.feature_id
                  JOIN dbxref dbx ON fdbx.dbxref_id = dbx.dbxref_id
                  JOIN db ON dbx.db_id = db.db_id
                  JOIN LATERAL (
             SELECT array_length(regexp_split_to_array(regexp_replace(props, 'diopt methods:\s+', ''), ',\s*'),
                                 1) AS score
             FROM regexp_split_to_table(fr.value, '\n+') AS props
             WHERE props ILIKE 'diopt methods:%'
             ) diopt ON TRUE
         WHERE o.genus = 'Homo'
           and o.species = 'sapiens'
           AND position('diopt methods' in fr.value) > 0
           AND db.name = 'HGNC'
           AND diopt.score > 2
        )
;

ALTER TABLE gene_group.pathway_member
    ADD COLUMN id SERIAL PRIMARY KEY;

CREATE INDEX pathway_member_idx1 ON gene_group.pathway_member (fbgg_id);
CREATE INDEX pathway_member_idx2 ON gene_group.pathway_member (fbgn_id);
CREATE INDEX pathway_member_idx3 ON gene_group.pathway_member (antibody);
CREATE INDEX pathway_member_idx4 ON gene_group.pathway_member (group_member_label);
ALTER TABLE gene_group.pathway_member
    ADD CONSTRAINT pathway_member_fk1 FOREIGN KEY (fbgg_id) REFERENCES gene_group.pathway (uniquename);

/**
  This table tracks membership of genes in other gene groups.
 */
DROP TABLE IF EXISTS gene_group.gene_group_membership CASCADE;
CREATE TABLE gene_group.gene_group_membership
AS
SELECT member.fbgn_id,
       member.id AS pathway_member_id,
       (SELECT jsonb_agg(jsonb_build_object('id', grp.uniquename, 'name', flybase.current_fullname(grp.uniquename)))
        FROM feature_grpmember fg
                 JOIN grpmember gm ON fg.grpmember_id = gm.grpmember_id
                 JOIN cvterm cvt ON gm.type_id = cvt.cvterm_id
                 JOIN grp on gm.grp_id = grp.grp_id
        WHERE cvt.name = 'grpmember_feature'
          AND gene_group.is_pathway(grp.uniquename) = false
          AND fg.feature_id = f.feature_id
       )         AS gene_groups,
       (SELECT jsonb_agg(jsonb_build_object('id', grp.uniquename, 'name', flybase.current_fullname(grp.uniquename)))
        FROM feature_grpmember fg
                 JOIN grpmember gm ON fg.grpmember_id = gm.grpmember_id
                 JOIN cvterm cvt ON gm.type_id = cvt.cvterm_id
                 JOIN grp on gm.grp_id = grp.grp_id
        WHERE cvt.name = 'grpmember_feature'
          AND gene_group.is_pathway(grp.uniquename) = true
          AND fg.feature_id = f.feature_id
          AND grp.uniquename != member.fbgg_id
       )         AS other_pathways
FROM gene_group.pathway_member AS member
         JOIN feature f ON f.uniquename = member.fbgn_id
;


CREATE INDEX gene_group_membership_idx1 ON gene_group.gene_group_membership (fbgn_id);
CREATE INDEX gene_group_membership_idx2 ON gene_group.gene_group_membership (pathway_member_id);

ALTER TABLE gene_group.gene_group_membership
    ADD CONSTRAINT gene_group_membership_fk1 FOREIGN KEY (pathway_member_id) REFERENCES gene_group.pathway_member (id);
/**
 */
DROP TABLE IF EXISTS gene_group.pathway_disease CASCADE;
CREATE TABLE gene_group.pathway_disease
AS
SELECT distinct on (member.fbgn_id, dbx.accession, qualifier, is_experimental, member.id) member.fbgn_id,
                                                                                          jsonb_build_object(
                                                                                                  'id',
                                                                                                  db.name || ':' || dbx.accession,
                                                                                                  'name',
                                                                                                  cvt.name,
                                                                                                  'qualifier',
                                                                                                  qualifier.value
                                                                                              )     AS disease,
                                                                                          CASE
                                                                                              WHEN ec.value ~ '\y(CEC|CEA)\y'
                                                                                                  THEN true
                                                                                              ELSE false
                                                                                              END   AS is_experimental,
                                                                                          member.id AS pathway_member_id
FROM gene_group.pathway_member AS member
         JOIN feature g ON g.uniquename = member.fbgn_id
         JOIN gene.allele ON gene.allele.gene_id = g.feature_id
         JOIN feature a ON gene.allele.fbal_id = a.uniquename
         JOIN feature_cvterm fcvt ON a.feature_id = fcvt.feature_id
         LEFT JOIN (
    SELECT qual.feature_cvterm_id, qual.value
    FROM feature_cvtermprop qual
             JOIN cvterm qt ON qual.type_id = qt.cvterm_id
    WHERE qt.name = 'qualifier'
      AND position('model of' IN qual.value) > 0
) AS qualifier ON fcvt.feature_cvterm_id = qualifier.feature_cvterm_id
         JOIN feature_cvtermprop ec ON fcvt.feature_cvterm_id = ec.feature_cvterm_id
         JOIN cvterm ect ON ec.type_id = ect.cvterm_id
         JOIN cvterm cvt ON fcvt.cvterm_id = cvt.cvterm_id
         JOIN cv ON cvt.cv_id = cv.cv_id
         JOIN dbxref dbx ON cvt.dbxref_id = dbx.dbxref_id
         JOIN db ON dbx.db_id = db.db_id
WHERE cv.name = 'disease_ontology'
  AND db.name = 'DOID'
  AND ect.name = 'evidence_code'
  AND ec.value ~ '\y(CEC|CEA|IEA)\y'

UNION

SELECT distinct on (member.fbgn_id, dbx.accession, qualifier, is_experimental, member.id) member.fbgn_id,
                                                                                          jsonb_build_object(
                                                                                                  'id',
                                                                                                  db.name || ':' || dbx.accession,
                                                                                                  'name',
                                                                                                  cvt.name,
                                                                                                  'qualifier',
                                                                                                  qualifier.value
                                                                                              )     AS disease,
                                                                                          CASE
                                                                                              WHEN ec.value ~ '\y(CEC|CEA)\y'
                                                                                                  THEN true
                                                                                              ELSE false
                                                                                              END   AS is_experimental,
                                                                                          member.id AS pathway_member_id
FROM gene_group.pathway_member AS member
         JOIN feature g ON g.uniquename = member.fbgn_id
         JOIN feature_cvterm fcvt ON g.feature_id = fcvt.feature_id
         LEFT JOIN (
    SELECT qual.feature_cvterm_id, qual.value
    FROM feature_cvtermprop qual
             JOIN cvterm qt ON qual.type_id = qt.cvterm_id
    WHERE qt.name = 'qualifier'
      AND position('model of' IN qual.value) > 0
) AS qualifier ON fcvt.feature_cvterm_id = qualifier.feature_cvterm_id
         JOIN feature_cvtermprop ec ON fcvt.feature_cvterm_id = ec.feature_cvterm_id
         JOIN cvterm ect ON ec.type_id = ect.cvterm_id
         JOIN cvterm cvt ON fcvt.cvterm_id = cvt.cvterm_id
         JOIN cv ON cvt.cv_id = cv.cv_id
         JOIN dbxref dbx ON cvt.dbxref_id = dbx.dbxref_id
         JOIN db ON dbx.db_id = db.db_id
WHERE cv.name = 'disease_ontology'
  AND db.name = 'DOID'
  AND ect.name = 'evidence_code'
  AND ec.value ~ '\y(CEC|CEA|IEA)\y'
;

CREATE INDEX pathway_disease_idx1 ON gene_group.pathway_disease (pathway_member_id);
CREATE INDEX pathway_disease_idx2 ON gene_group.pathway_disease (is_experimental);

ALTER TABLE gene_group.pathway_disease
    ADD CONSTRAINT pathway_disease_fk1 FOREIGN KEY (pathway_member_id) REFERENCES gene_group.pathway_member (id);


