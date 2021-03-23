#!/usr/bin/env python3
import re
import sys

import psycopg2

"""
Program: find_overlapping_miRNA_mRNA.py
Author: Josh Goodman

QuickStart:

./find_overlapping_miRNA_mRNA.py file_with_locations.txt > overlapping_features.txt

Description:

This script takes a file of newline delimited scaffold locations and returns a TSV
file with all annotated mRNA and miRNA features that overlap with these locations.

Scaffold locations are expected to use the form of <SCAFFOLD NAME>:<MIN>..<MAX>

e.g. 3L:37238..59593

This script uses the FlyBase public Chado database to find the overlapping
features.

More information about this database is available at:
https://flybase.github.io/docs/chado/index

Installation:

This script requires the PostrgreSQL python client psycopg2 to query the Chado database.
If not already installed, it is recommended that you setup a python virtual environment to
install it.

# Create virtual python environment
python3 -m venv venv
# Activate environment
source venv/bin/activate
# Install psycopg2
pip install psycopg2
./find_overlapping_miRNA_mRNA.py file_with_locations.txt > output.txt
"""

# Public FlyBase Chado DB connection details.
chado_db = {
    'dbname': 'flybase',
    'user': 'flybase',
    'host': 'chado.flybase.org'
}

# Dictionary to hold scaffold feature IDs
scaffold_ids = {}
# Sequence coordinate regex
location_regex = re.compile(r'^(?P<scaffold>\w+):(?P<fmin>\d+)\.\.(?P<fmax>\d+)$')


def get_scaffold_id(conn, scaffold_name: str = None, genus: str = 'Drosophila', species: str = 'melanogaster',
                    scaffold_type: str = 'golden_path'):
    """
    Fetches the feature.feature_id of the specified scaffold feature from Chado.
    This function assumes that only one unique scaffold per organism exists.

    :param conn: The psycopg2 connection object for the Chado database.
    :param scaffold_name: The name of the scaffold to lookup.
    :param genus: The genus of the scaffold organism. default: 'Drosophila'
    :param species: The species of the scaffold organism. default: 'melanogaster'
    :param scaffold_type: The feature type of the scaffold. default: 'golden_path'
    :return: The Chado feature.feature_id of the scaffold feature.
    """
    if scaffold_name is None:
        raise ValueError("No scaffold name specified.")

    scaffold_id_query = """
    select feature_id
        from feature f join organism o on f.organism_id = o.organism_id
                       join cvterm cvt on f.type_id = cvt.cvterm_id 
        where o.genus = %s
          and o.species = %s
          and cvt.name = %s
          and f.is_obsolete = false
          and f.is_analysis = false
          and f.name = %s
    """
    cur = conn.cursor()
    cur.execute(scaffold_id_query, (genus, species, scaffold_type, scaffold_name))
    return cur.fetchone()[0]


def get_location_dict(location: str):
    """
    Parse the location string into a dictionary with
    the scaffold name, fmin, and fmax

    :param location: Location string in the format of <SCAFFOLD>:<FMIN>..<FMAX>
    :return: Dictionary with scaffold, fmin, and fmax attributes.
    """
    formatted_loc = location.strip().replace(',', '')
    match = location_regex.match(formatted_loc)
    if match:
        return match.groupdict()

    return None


def get_overlapping_miRNA_mRNA(conn, location: dict = {}):
    """
    Takes a Chado database connection, a location, and returns a dictionary of all miRNA /
    mRNA features that overlap the given location.

    :param conn: The psycopg2 connection object for the Chado database.
    :param location: Dictionary containing the featureloc fields (srcfeature_id, scaffold, fmin, and fmax)
    :return: Dictionary containing FlyBase ID as key and a tuple of FlyBase ID, symbol, and feature type.
    """
    # SQL query to look for overlapping transcript features.
    miRNA_mRNA_query = """
    select f.uniquename,
           flybase.current_symbol(f.uniquename),
           cvt.name
        from featureloc_slice(%s, %s, %s) as fl join feature f on fl.feature_id=f.feature_id
                                                join cvterm cvt on f.type_id=cvt.cvterm_id
        where f.uniquename ~ '^FBtr\d+$'
            and f.is_obsolete = false
            and f.is_analysis = false
            and cvt.name in ('miRNA','mRNA')
        ;
    """
    cur = conn.cursor()
    cur.execute(miRNA_mRNA_query, (location['srcfeature_id'], location['fmin'], location['fmax']))
    # Return a dictionary containing all miRNA and mRNA features that overlap the given location.
    # The dictionary key is the FBtr ID and the value is a tuple with FBtr ID, symbol, and feature type.
    return {r[0]: r for r in cur}


if __name__ == '__main__':
    # Get file with locations.
    location_file = sys.argv[1]
    # Connect to Chado DB.
    conn = psycopg2.connect(**chado_db)
    try:
        with open(location_file, 'r') as fh:
            for location in fh:
                # Parse location strings into a dictionary.
                parsed_location = get_location_dict(location)
                name = parsed_location['scaffold']
                # Lookup the scaffold feature_id in Chado if we don't already have it.
                if name not in scaffold_ids:
                    scaffold_ids[name] = get_scaffold_id(conn, name)

                # Add the feature_id of the scaffold to the parsed_location object
                # as a srcfeature_id attribute. Looking up the scaffold ID is a
                # performance optimization step for the overlap lookup step.
                parsed_location['srcfeature_id'] = scaffold_ids[name]

                # Get all overlapping mRNA/miRNA features for this location.
                features = get_overlapping_miRNA_mRNA(conn, parsed_location)

                # Print results.
                if len(features) > 0:
                    for fbtr, feature in features.items():
                        print(f'{location.strip()}\t{fbtr}\t{feature[1]}\t{feature[2]}')

    except ValueError as e:
        print(f'ERROR: {e}', file=sys.stderr)
    finally:
        conn.close()
