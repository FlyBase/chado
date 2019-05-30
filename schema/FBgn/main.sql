create schema if not exists flybase;

drop materialized view if exists flybase.gene;

create materialized view if not exists flybase.gene
  as select f.*
      from feature f join cvterm cvt on (f.type_id=cvt.cvterm_id)
      where f.uniquename ~ '^FBgn[0-9]+$'
        and f.is_analysis = false
        and f.is_obsolete = false
        and cvt.name = 'gene'
;
  
