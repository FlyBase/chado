#!/usr/bin/env python
"""
Program: conserved_darkened_genes.py
Author: Josh Goodman
Description:

This script started as a first pass attempt at trying to answer a question posed
by Dr. Arash Bashirullah of the University of Wisconsin.  Dr. Bashirullah wanted
to know the following: Of all the Dmel genes, which ones do we know very little
about but are known to be highly conserved across many organisms.

This script tries to answer this question by using two simple criteria for
selecting genes.

1. Generate a list of genes that have terms from 1 or less GO aspects
(molecular_function, biological_process, or cellular_component).
Terms based on predictions or those that are qualified with 'NOT'
were ignored.

2. Generate a list of genes that are conserved across all species in
the DIOPT meta orthology tool.  Currently, DIOPT has data on 10
species from 18 orthology algorithms.

The intersection of these two lists is one possible answer to this question.

"""

import pandas as pd
import argparse
from sqlalchemy import create_engine

"""
Name: setup_go_func
Description:

This python function creates a temporary PostgreSQL SQL function that will return a count of 
experimental GO terms for the given GO aspect.  GO aspects can be either biological_process,
molecular_function, or cellular_component.  The SQL function takes a gene ID (FBgn) and
the GO aspect that you wish to retrieve the count for.

This python function takes a SQLAlchemy connection object, creates the function in the 
pg_temp temporary schema, and then returns back to the caller.

The PostgreSQL function can then be called in later SQL statements anywhere in this program.

e.g.
select pg_temp.experimental_go_count('FBgn0000490','biological_process');

Arguments:
    conn - A SQLAlchemy Connection object.

Returns:
    None
"""


def setup_go_func(conn):
    conn.execute("""
    create function pg_temp.experimental_go_count(fbgn text, aspect text) returns integer as $$
    select count(distinct cvt.name)::integer
       from feature f join feature_cvterm fcvt on (f.feature_id=fcvt.feature_id)
                      join cvterm cvt on (fcvt.cvterm_id=cvt.cvterm_id)
                      join cv on (cvt.cv_id=cv.cv_id)
                      join feature_cvtermprop ev_code on (fcvt.feature_cvterm_id=ev_code.feature_cvterm_id)
                      join cvterm ev_code_type on (ev_code.type_id=ev_code_type.cvterm_id)
       where f.uniquename = $1 -- The gene ID to fetch terms for.
          and cv.name = $2     -- The GO aspect to fetch terms for.
          -- The following ignores terms that have been annotated with 'NOT'
          and (select fcvtp_type.name
                 from feature_cvtermprop fcvtp join cvterm fcvtp_type on (fcvtp.type_id=fcvtp_type.cvterm_id)
                 where fcvtp.feature_cvterm_id = fcvt.feature_cvterm_id
                   and fcvtp_type.name = 'NOT'
              ) is null
          -- Select only experimental terms, no annotations from predictions.
          and ev_code_type.name = 'evidence_code'
          and ev_code.value ~
          'inferred from (physical interaction|direct assay|genetic interaction|mutant phenotype|expression pattern|(high throughput (experiment|direct assay|expression pattern|genetic interaction|mutant phenotype)))'
    $$ language sql;
    """)


"""
Name: fetch_go_counts
Description:

This function queries a FlyBase Chado database and returns a list of all FlyBase genes
that have been localized to the genome.  The columns include the FlyBase FBgn ID, the
gene symbol, term counts by GO aspect, and the number of aspects with more than 0 terms.


Arguments:
    conn - A SQLAlchemy Connection object.

Returns:
    DataFrame - A Data frame with the gene ID, symbol, term counts for all 3 GO aspects, and
                the number of aspects with more than 0 terms.
"""


def fetch_go_counts(conn):
    # Install a SQL function that is used by this function.
    setup_go_func(conn)

    # The Following SQL returns GO term counts for all GO aspects for Dmel genes
    # that have been localized to the genome.
    fbgn_go_counts_sql = """
    select gene.uniquename as fbid,
           flybase.current_symbol(gene.uniquename) as symbol,
           pg_temp.experimental_go_count(gene.uniquename,'biological_process') as biological_process,
           pg_temp.experimental_go_count(gene.uniquename,'molecular_function') as molecular_function,
           pg_temp.experimental_go_count(gene.uniquename,'cellular_component') as cellular_component
        from feature gene join cvterm cvt on (gene.type_id=cvt.cvterm_id)
                          join organism org on (gene.organism_id=org.organism_id)
                          join featureloc fl on (gene.feature_id=fl.feature_id)
        where gene.uniquename ~ '^FBgn[0-9]+$'
          and gene.is_obsolete = false
          and gene.is_analysis = false
          and cvt.name = 'gene'
          and org.genus = 'Drosophila' and org.species = 'melanogaster'
    ;
    """
    df = pd.read_sql(fbgn_go_counts_sql, conn, index_col='fbid')
    # Counts the number of GO aspect columns with non zero values and adds it as a new
    # column to the DataFrame as 'num_aspects'.
    df['num_aspects'] = df[['biological_process', 'molecular_function', 'cellular_component']].astype(bool).sum(axis=1)
    return df


"""
Name: fetch_ortholog_counts
Description:

This function queries a FlyBase Chado database and returns a DataFrame containing the FlyBase gene ID
and the number of species that are reported by DIOPT in orthology calls.  No filtering of calls by
score is attempted here, which could be a source of furture improvements.

Arguments:
    conn - A SQLAlchemy Connection object.

Returns:
    DataFrame - A DataFrame with the FlyBase gene ID and the number of species in the DIOPT reported
                orthology calls.
"""


def fetch_ortholog_counts(conn):
    # SQL to fetch counts of species in orthology calls for all Dmel genes that are localized to the genome.
    ortholog_counts_sql = """
            select gene.uniquename as fbid,
                   count(distinct fbog.organism_id) as num_ortho_species
                from feature gene join feature_relationship ortho_rel on (gene.feature_id=ortho_rel.object_id)
                                  join feature fbog on (ortho_rel.subject_id=fbog.feature_id)
                                  join cvterm fr_type on (ortho_rel.type_id=fr_type.cvterm_id)
                                  join feature_relationshipprop frp on (ortho_rel.feature_relationship_id=frp.feature_relationship_id)
                                  join organism org on (gene.organism_id=org.organism_id)
                                  join cvterm cvt on (gene.type_id=cvt.cvterm_id)
                                  join featureloc fl on (gene.feature_id=fl.feature_id)
                where gene.uniquename ~ '^FBgn[0-9]+$'
                  and gene.is_analysis = false
                  and gene.is_obsolete = false
                  and cvt.name = 'gene'
                  and fbog.is_analysis = false
                  and fbog.is_obsolete = false
                  and fr_type.name = 'orthologous_to'
                  and frp.value = 'DIOPT'
                  and org.genus = 'Drosophila'
                  and org.species ='melanogaster'
            group by gene.uniquename
            ;
            """
    return pd.read_sql(ortholog_counts_sql, conn, index_col='fbid')


def main():
    # Setup the argument parser.
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", help="Chado database hostname.", default="chado.flybase.org")
    parser.add_argument("-U", "--username", help="Chado database username.", default="flybase")
    parser.add_argument("-W", "--password", help="Chado database password.")
    parser.add_argument("-d", "--dbname", help="Chado database password.", default="flybase")
    parser.add_argument("-p", "--port", help="Chado database port.", default=5432, type=int)
    args = parser.parse_args()

    # Init the SQLAlchemy engine and connect.
    engine = create_engine(
        'postgresql+psycopg2://{}:{}@{}:{}/{}'.format(args.username, args.password, args.host, args.port, args.dbname),
        client_encoding='utf8')
    conn = engine.connect()

    # Fetch GO counts and store them to a CSV file.
    go_counts = fetch_go_counts(conn)
    go_counts.to_csv('dmel_go_counts.csv')

    # Select out genes with 1 or less GO aspects and store to a file.
    genes_few_go_aspects = go_counts[go_counts['num_aspects'] <= 1]
    genes_few_go_aspects.to_csv('dmel_few_go_aspects.csv')

    # Fetch ortholog counts and store to a file.
    gene_orthologs_species_count = fetch_ortholog_counts(conn)
    gene_orthologs_species_count.to_csv('dmel_orthologs_species_count.csv')

    # Calculate the intersection between the GO and orthology lists.
    merged_gene_list = pd.merge(genes_few_go_aspects, gene_orthologs_species_count, on='fbid')
    final_filename = 'conserved_darkened_genes.csv'
    print("Saving final gene list to {}".format(final_filename))
    # Save those genes from the merged list that are conserved across all current DIOPT species.
    merged_gene_list[merged_gene_list['num_ortho_species'] == 9].to_csv(final_filename)


if __name__ == "__main__":
    main()
