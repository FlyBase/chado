/**
    This file may eventually become the standard for this repo, but it has been created to solve some issues with
    making the data storage for gene groups more abstract to account for all gene groups, not just pathways.
*/

CREATE SCHEMA IF NOT EXISTS dataclass;

DROP TABLE IF EXISTS dataclass.allele CASCADE;
DROP TABLE IF EXISTS dataclass.geneV2 CASCADE;
DROP TABLE IF EXISTS dataclass.alleleV2 CASCADE;
DROP TABLE IF EXISTS dataclass.diseaseV2 CASCADE;
DROP TABLE IF EXISTS dataclass.enzymeV2 CASCADE;
DROP TABLE IF EXISTS dataclass.gene_groupV2 CASCADE;
DROP TABLE IF EXISTS dataclass.orthologV2 CASCADE;

DROP TABLE IF EXISTS dataclass_relationship.gene_diseaseV2 CASCADE;
DROP TABLE IF EXISTS dataclass_relationship.gene_enzymeV2 CASCADE;
DROP TABLE IF EXISTS dataclass_relationship.gene_go_molecular_functionV2 CASCADE;
DROP TABLE IF EXISTS dataclass_relationship.gene_group_memberV2 CASCADE;
DROP TABLE IF EXISTS dataclass_relationship.gene_human_orthologV2 CASCADE;
DROP TABLE IF EXISTS dataclass_relationship.gene_alleleV2 CASCADE;

-- Gene must be before allele since allele references gene
\ir gene.sql

\ir allele.sql
\ir disease.sql
\ir enzyme.sql
\ir gene_group.sql
\ir ortholog.sql

\ir ../data_class_relationships/main.sql

ALTER TABLE dataclass.gene RENAME TO geneV2;
ALTER TABLE dataclass.allele RENAME TO alleleV2;
ALTER TABLE dataclass.disease RENAME TO diseaseV2;
ALTER TABLE dataclass.enzyme RENAME TO enzymeV2;
ALTER TABLE dataclass.gene_group RENAME TO gene_groupV2;
ALTER TABLE dataclass.ortholog RENAME TO orthologV2;

ALTER TABLE dataclass_relationship.gene_disease RENAME TO gene_diseaseV2;
ALTER TABLE dataclass_relationship.gene_enzyme RENAME TO gene_enzymeV2;
ALTER TABLE dataclass_relationship.gene_go_molecular_function RENAME TO gene_go_molecular_functionV2;
ALTER TABLE dataclass_relationship.gene_group_member RENAME TO gene_group_memberV2;
ALTER TABLE dataclass_relationship.gene_human_ortholog RENAME TO gene_human_orthologV2;
ALTER TABLE dataclass_relationship.gene_allele RENAME TO gene_alleleV2;
