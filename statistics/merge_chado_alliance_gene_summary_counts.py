#!/usr/bin/env python3
import sys
import csv


def get_genes_with_summaries(alliance_gs_file: str):
    """
    Read in the Alliance gene summaries aka gene descriptions TSV file and
    return a Set with all FlyBase IDs that have a description.

    File may be obtained from https://www.alliancegenome.org/downloads

    :param alliance_gs_file: Path to file containing the Alliance gene summaries/descriptions.
    :return: set containing all FlyBase (FBgn) IDs with descriptions.
    """
    summaries = set()
    with open(alliance_gs_file, 'r') as alliance_fh:
        # Read in the Alliance
        reader = csv.DictReader(filter(lambda r: r[0] != '#', alliance_fh),
                                fieldnames=['fbgn', 'symbol', 'summary'], delimiter='\t')
        for row in reader:
            fbgn = row['fbgn'].replace('FB:', '', 1)
            if row['summary'].lower() != 'no description available':
                summaries.add(fbgn)
    return summaries


def merge_summary_stats(chado_summary_stats_file: str, alliance_summaries: set = set()):
    """
    Reads through the Chado summary stats file, adds the alliance gene description/summary data, and
    calculates the "selected summary" that would appear at the top of the gene report.

    :param chado_summary_stats:
    :param alliance_summaries:
    :return:
    """
    with open(chado_summary_stats_file, 'r') as chado_stats_fh:
        reader = csv.reader(chado_stats_fh, delimiter='\t')

        print(
            "#FBgn\tSymbol\tGene_Snapshot\tUniProt_Function\tFlyBase_Pathway\tFlyBase_Gene_Group\tInteractive_"
            "Fly\tAlliance_Gene_Description\tSelected"
        )

        for row in reader:
            # Append a 1 or 0 if this gene has an alliance gene summary/description.
            if row[0].startswith('FBgn') and row[0] in alliance_summaries:
                row.append("1")
            else:
                row.append("0")

            # Add the selected summary column.
            row.append(selected_summary(row[2:]))
            # Print the row with the 2 additional columns.
            print('\t'.join(row))

    return None


def selected_summary(summaries: list = []):
    """
    The gene summary selection algorithm used to select the summary that is displayed at the top of the
    gene report.

    :param summaries:  An ordered list containing counts of each gene summary type.
    :return: The name of the summary that would be selected given the list of counts.
    """
    selected = "Automatic summary"
    if int(summaries[0]) >= 1:
        selected = "Gene Snapshot"
    elif int(summaries[1]) >= 1:
        selected = "UniProt Function"
    elif int(summaries[2]) == 1:
        selected = "FlyBase Pathway"
    elif int(summaries[2]) > 1:
        selected = "FlyBase Pathway (multiple)"
    elif int(summaries[3]) == 1:
        selected = "FlyBase Gene Group"
    elif int(summaries[3]) > 1:
        selected = "FlyBase Gene Group (multiple)"
    elif int(summaries[4]) >= 1:
        selected = "Ineteractive Fly"
    elif int(summaries[5]) >= 1:
        selected = "Alliance Gene Description"
    return selected


if __name__ == '__main__':
    """
    Description:
    Takes a file with counts of various gene summary sources by gene from Chado and Alliance Gene Descriptions/Summaries
    and prints out summary statistics and the selected summary that is displayed at the top of the gene report.
    
    This script was used to model how the summaries would be assigned under a few methods.
    
    Usage:
    python3 ./merge_chado_alliance_gene_summary_counts.py chado_summary_counts.tsv alliance_summaries.tsv
    
    Result:
    A TSV sent to STDOUT showing counts of summaries for each gene in FlyBase and the summary that would
    be promoted to the top of the gene report.
    """
    alliance_summaries = get_genes_with_summaries(sys.argv[2])
    merge_summary_stats(sys.argv[1], alliance_summaries)
    exit(0)
