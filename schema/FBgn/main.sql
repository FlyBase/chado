create schema if not exists gene;

DROP TABLE IF EXISTS gene.gene;

CREATE TABLE gene.gene
  as select f.*
      from feature f join cvterm cvt on (f.type_id=cvt.cvterm_id)
      where f.uniquename ~ '^FBgn[0-9]+$'
        and f.is_analysis = false
        and f.is_obsolete = false
        and cvt.name = 'gene'
;