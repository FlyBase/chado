/**
  SQL used to generate the counts of gene summaries for all genes in Chado.

  e.g.
  psql -f gene_summary_stats.sql -h chado.flybase.org -U flybase flybase > gene_summary_chado_stats.tsv

  This file is then consumed by merge_chado_alliance_gene_summary_counts.py to produce the final file.
 */
copy (
select
  f.uniquename,
  flybase.current_symbol(f.uniquename),
  gene_snapshot,
  uniprot_function,
  flybase_pathway,
  flybase_group,
  interactive_fly
  from feature f
    left join lateral (
      select count(*) as gene_snapshot
      from flybase.get_featureprop(f.uniquename,'gene_summary_text')
    ) gs on true

    left join lateral (
      select count(*) as uniprot_function
      from feature_dbxref fdbx join dbxref dbx on fdbx.dbxref_id = dbx.dbxref_id
                               join dbxrefprop dbxp on dbx.dbxref_id = dbxp.dbxref_id
                               join db on dbx.db_id = db.db_id
                               join cvterm dbxpt on dbxp.type_id = dbxpt.cvterm_id
      where f.feature_id = fdbx.feature_id 
        and lower(dbxpt.name) = 'uniprot_function_comment'
        and lower(db.name) = 'uniprot/swiss-prot'
    ) us on true

    left join lateral (
      select count(*) as flybase_pathway
      from feature_grpmember fgm join grpmember gm on fgm.grpmember_id = gm.grpmember_id
                                 join cvterm gmt on gm.type_id = gmt.cvterm_id
                                 join grp on gm.grp_id = grp.grp_id
                                 join grp_cvterm g_cvt on grp.grp_id = g_cvt.grp_id
                                 join cvterm gt on g_cvt.cvterm_id = gt.cvterm_id
                                 join dbxref dbx on gt.dbxref_id = dbx.dbxref_id
                                 join db on dbx.db_id = db.db_id
      where f.feature_id = fgm.feature_id 
        and gmt.name = 'grpmember_feature'
        and db.name = 'FBcv'
        and dbx.accession = '0003017'
    ) fbpath on true

    left join lateral (
      select count(*) as flybase_group
      from feature_grpmember fgm join grpmember gm on fgm.grpmember_id = gm.grpmember_id
                                 join cvterm gmt on gm.type_id = gmt.cvterm_id
                                 join grp on gm.grp_id = grp.grp_id
                                 join grp_cvterm g_cvt on grp.grp_id = g_cvt.grp_id
                                 join cvterm gt on g_cvt.cvterm_id = gt.cvterm_id
                                 join dbxref dbx on gt.dbxref_id = dbx.dbxref_id
                                 join db on dbx.db_id = db.db_id
      where f.feature_id = fgm.feature_id 
        and gmt.name = 'grpmember_feature'
        and db.name = 'FBcv'
        and dbx.accession != '0003017'
    ) fbgroup on true

    left join lateral (
      select count(*) as interactive_fly
      from feature_dbxref fdbx join dbxref dbx on fdbx.dbxref_id = dbx.dbxref_id
                               join dbxrefprop dbxp on dbx.dbxref_id = dbxp.dbxref_id
                               join db on dbx.db_id = db.db_id
                               join cvterm dbxpt on dbxp.type_id = dbxpt.cvterm_id
      where f.feature_id = fdbx.feature_id 
        and lower(dbxpt.name) = 'if_summary'
        and lower(db.name) = 'interactivefly'
        and dbxp.value is not null
    ) if on true

  where f.is_obsolete = false
    and f.is_analysis = false
    and f.uniquename ~ '^FBgn\d+$'
) to stdout;
