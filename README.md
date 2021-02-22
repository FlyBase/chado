# Chado

Chado related code for FlyBase

## Scripts

### Statistics

**[data_class_counts.pl](statistics/data_class_counts.pl) -**
A script for calculating counts of FlyBase data classes for a release.

**[merge_chado_alliance_gene_summary_counts.py](statistics/merge_chado_alliance_gene_summary_counts.py) -**
A script for calculating counts of various types of gene summaries by gene.

**[gene_summary_stats.sql](statistics/gene_summary_stats.sql) -**
SQL used for generating gene summary counts from Chado


### Pathways and metabolism

**[extend_ec_data.pl](enzyme_commission/extend_ec_data.pl) -**
A script for pulling in Enzyme metadata and adding it to EC dbxref entries in Chado.

### Misc

**[conserved_darkened_genes.py](misc/conserved_darkened_genes.py) -**

A script for extracting genes with sparse GO annotations and which are
highly conserved across many species.


## Schema

## Utility functions

**[IDs](schema/ids/) -**
FlyBase ID related functions for Chado.

