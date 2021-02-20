#!/usr/bin/env python3
import sys
import csv
import re


def process_stat_files(ga_stats_file: str, redfly_file: str):
    fbsf_re = re.compile(r'FBsf\d+')

    with open(redfly_file, 'r') as redfly_fh:
        redfly_counts = dict.fromkeys(redfly_fh.read().splitlines(), 0)

    with open(ga_stats_file, newline='') as csv_fh:
        ga_reader = csv.reader(csv_fh)
        for row in ga_reader:
            try:
                if 'FBsf' in row[0]:
                    match = fbsf_re.search(row[0])
                    if match:
                        fbsf = match.group(0)
                        if fbsf in redfly_counts:
                            redfly_counts[fbsf] += 1

            except IndexError:
                pass

    return redfly_counts


if __name__ == '__main__':
    counts = process_stat_files(sys.argv[1], sys.argv[2])
    for key, value in counts.items():
        if value > 0:
            print(f'{key}\t{value}')
    exit(0)
