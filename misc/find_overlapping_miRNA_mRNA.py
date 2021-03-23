#!/usr/bin/env python3
import sys
import re
import psycopg2

chado_db = {
    'dbname': 'flybase',
    'user': 'flybase',
    'host': 'chado.flybase.org'
}

# Dictionary to hold scaffold feature IDs
scaffold_ids = {}
location_regex = re.compile(r'^(?P<scaffold>\w+):(?P<fmin>\d+)\.\.(?P<fmax>\d+)$')


def get_scaffold_id(conn, scaffold_name: str = None, genus: str = 'Drosophila', species: str = 'melanogaster', scaffold_type: str = 'golden_path'):
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


def get_overlapping_miRNA_mRNA(conn, location:dict = {}):
    """

    :param conn: The psycopg2 connection object for the Chado database.
    :param location: Dictionary containing the featureloc fields (srcfeature_id (scaffold, fmin, and fmax)
    :return:
    """
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
    location_file = sys.argv[1]
    conn = psycopg2.connect(**chado_db)
    try:
        with open(location_file, 'r') as fh:
            for location in fh:
                parsed_location = get_location_dict(location)
                name = parsed_location['scaffold']
                if name not in scaffold_ids:
                    scaffold_ids[name] = get_scaffold_id(conn, name)

                parsed_location['srcfeature_id'] = scaffold_ids[name]
                features = get_overlapping_miRNA_mRNA(conn, parsed_location)
                if len(features) > 0:
                    for fbtr, feature in features.items():
                        print(f'{location.strip()}\t{fbtr}\t{feature[1]}\t{feature[2]}')

    except ValueError as e:
        print(f'ERROR: {e}', file=sys.stderr)
    finally:
        conn.close()


