CREATE SCHEMA IF NOT EXISTS gene;

DROP TABLE IF EXISTS gene.gene;

CREATE TABLE gene.gene
  AS SELECT f.*
      FROM feature f JOIN cvterm cvt ON (f.type_id=cvt.cvterm_id)
      WHERE f.uniquename ~ '^FBgn[0-9]+$'
        AND f.is_analysis = false
        AND f.is_obsolete = false
        AND cvt.name = 'gene'
;

ALTER TABLE gene.gene ADD PRIMARY KEY (feature_id);
CREATE INDEX gene_gene_idx1 ON gene.gene (uniquename);
CREATE INDEX gene_gene_idx2 ON gene.gene (name);
