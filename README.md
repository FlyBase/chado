# Chado

Chado related code for FlyBase

## Scripts

### Statistics

**[data_class_counts.pl](statistics/data_class_counts.pl) -**
A script for calculating counts of FlyBase data classes for a release.

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

