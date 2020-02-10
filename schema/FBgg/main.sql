CREATE SCHEMA IF NOT EXISTS gene_group;

CREATE OR REPLACE FUNCTION gene_group.is_pathway(fbgg text, cvid varchar default '0003017') RETURNS bool AS
$$
SELECT EXISTS(
               SELECT 1
               FROM grp_cvterm gcvt
                        JOIN cvterm cvt ON (gcvt.cvterm_id = cvt.cvterm_id)
                        JOIN dbxref dbx ON (cvt.dbxref_id = dbx.dbxref_id)
                        JOIN db ON (dbx.db_id = db.db_id)
               WHERE upper(db.name) = 'FBCV'
                 AND dbx.accession = '0003017'
                 AND gcvt.grp_id = grp.grp_id
           )
FROM grp
WHERE grp.uniquename = fbgg
    ;
$$ LANGUAGE SQL STABLE;


DROP TABLE IF EXISTS gene_group.pathway CASCADE;

CREATE TABLE gene_group.pathway
AS
SELECT grp.*
FROM grp
WHERE grp.uniquename ~ '^FBgg[0-9]+$'
  AND grp.is_analysis = false
  AND grp.is_obsolete = false
  AND gene_group.is_pathway(grp.uniquename) = true
;


ALTER TABLE gene_group.pathway ADD COLUMN fullname text DEFAULT NULL;
UPDATE gene_group.pathway SET fullname = (SELECT flybase.current_fullname(uniquename));

ALTER TABLE gene_group.pathway
    ADD PRIMARY KEY (grp_id);
CREATE UNIQUE INDEX pathway_idx1 ON gene_group.pathway (uniquename);
CREATE INDEX pathway_idx2 ON gene_group.pathway (name);

