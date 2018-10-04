select distinct on (dbxref_id)
       ec.accession as ec,
       ec.dbxref_id as dbxref_id,
       'GO:' || dbx.accession as accession,
       cv.name as CV,
       cvt.name as cvname
  from db join dbxref ec on (db.db_id=ec.db_id)
          join cvterm_dbxref cvtdbx on (ec.dbxref_id=cvtdbx.dbxref_id)
          join cvterm cvt on (cvtdbx.cvterm_id=cvt.cvterm_id)
          join cv on (cvt.cv_id=cv.cv_id)
          join dbxref dbx on (cvt.dbxref_id=dbx.dbxref_id)
  where db.name='EC'
    and cvt.is_obsolete=0
;
