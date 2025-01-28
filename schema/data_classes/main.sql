/**
    This file may eventually become the standard for this repo, but it has been created to solve some issues with
    making the data storage for gene groups more abstract to account for all gene groups, not just pathways.
*/

CREATE SCHEMA IF NOT EXISTS dataclass;

-- Gene must be before allele since allele references gene
\ir gene.sql

\ir allele.sql
\ir disease.sql
\ir enzyme.sql
\ir gene_group.sql
\ir ortholog.sql

\ir ../data_class_relationships/main.sql
