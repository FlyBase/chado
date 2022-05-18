-- Import ID utility functions
\ir data_classes/utils.sql

-- Import FBgn ID updater.
\ir ids/id_updater.sql

-- Symbol related functions.
\ir symbols/main.sql

-- Relationship functions (feature_relationship, etc.).
\ir relationships/get_relationship.sql

-- Property functions (featureprop, etc.).
\ir properties/get_prop.sql

-- Cvterm related code.
\ir cvterms/gene_ontology.sql

-- Gene
\ir FBgn/main.sql

-- Stocks
\ir FBst/main.sql

-- Cell lines
\ir FBtc/main.sql

-- Pubs
\ir FBrf/main.sql

-- Gene Groups
\ir FBgg/main.sql

-- Datasets
\ir FBlc/main.sql
