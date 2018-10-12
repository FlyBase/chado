#!/usr/bin/env perl
use strict;
use warnings;

use 5.010;
use autodie;

use DBI;
use POSIX qw/cuserid/;
use Getopt::Long;
use Pod::Usage;
use Path::Tiny;
use Try::Tiny;

=pod

=head1 NAME

extend_ec_data.pl - Extends Enzyme Commission (EC) data in Chado.

=head1 SYNOPSIS

 extend_ec_data.pl [options]

 Options:
 --database The database to query
 --hostname The database hostname
 --username The database user
 --password The database user password
 --port     The database port
 --help     Print a help message
 --verbose  Print extra information to STDERR
 --man      Show a man page help doc.
    
see L<Options> for full details.

 e.g.
 ./extend_ec_data.pl --database FB2015_04
 ./extend_ec_data.pl --hostname myserver.com --username johnsmith --password mypassword --database FB2015_03

=head1 DESCRIPTION

This script adds additional metadata from the Enzyme Commission database
to EC numbers that are associated with GO terms in Chado.

It pulls down an updated copy of the Enzyme database, queries Chado
for all existing EC numbers associated with GO terms, and adds the
EC Description (DE), EC Catalytic activity (CA), and EC class to
the EC dbxref entry in Chado as a dbxrefprop.

  cvterm[GO Term] -> cvterm_dbxref-> dbxref[EC] --> dbxrefprop

The dbxrefprop types used are below.
They are inserted into the Chado instance if they are not found.

 * ec_class
 * ec_catalytic_activity
 * ec_description

Multiple props of the same type per EC number are possible.  In these
cases the dbxrefprop.rank column is used to distinguish them.

For example, these 3 lines in the enzyme database file 

  CA ATP + [biotin carboxyl-carrier protein]-biotin-N(6)-L-lysine +
  CA hydrogencarbonate- = ADP + phosphate + [biotin carboxyl-carrier protein]-
  CA carboxybiotin-N(6)-L-lysine.

will be converted into 3 dbxrefprops of type 'ec_catalytic_activity' and 
rank 0, 1, and 2.

=head2 Options

=over 5

=item --database <database name>

The database name to connect to.  

=item --hostname <host>

The hostname of the database server.  Defaults to 'localhost'.

=item --username <user>

The database username to use for connecting.  Defaults to the current user running the script.

=item --password <user>

The database password to use for connecting.

=item --port <port>

The database port to use for connecting.

=item --help 

Print a help page.

=item --verbose

Print extra information to STDERR during conversion.

=item --man

Show help as a man page.

=back

=head2 Dependencies

=over 5

=item B<Perl modules>

=item L<DBI>

=item L<POSIX>

=item L<Getopt::Long>

=item L<Pod::Usage>

=item L<Path::Tiny>

=item L<Try::Tiny>

=item B<Command line tools>

=item wget, L<https://www.gnu.org/software/wget/>

=back

=head1 AUTHOR

=over 5

=item Josh Goodman, FlyBase

=back


=head1 LICENSE

 Copyright (c) 2018, Indiana University & FlyBase 
 All rights reserved. 

 Redistribution and use in source and binary forms, with or without modification, 
 are permitted provided that the following conditions are met: 

  * Redistributions of source code must retain the above copyright 
    notice, this list of conditions and the following disclaimer. 
  * Redistributions in binary form must reproduce the above copyright 
    notice, this list of conditions and the following disclaimer in the 
    documentation and/or other materials provided with the distribution. 
  * Neither the name of Indiana University, Bloomington nor the names 
    of its contributors may be used to endorse or promote products 
    derived from this software without specific prior written 
    permission. 

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND 
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED 
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE 
 DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR 
 ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES 
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; 
 LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON 
 ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT 
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS 
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 

=cut

my $verbose      = 0;
my $help         = 0;
my $man          = 0;
my $host         = 'localhost';
my $username     = cuserid();
my $password     = '';
my $port         = 5432;
my $db; 

my $ec_proptypes = {
  DE    => 'ec_description',
  CA    => 'ec_catalytic_activity',
  class => 'ec_class',
};

my $getopt = GetOptions(
    'help|?'            => \$help,
    'verbose|v'         => \$verbose,
    'man'               => \$man,
    'hostname|host=s'   => \$host,
    'username|user=s'   => \$username,
    'password|passwd=s' => \$password,
    'database|db=s'     => \$db,
    'port=i'            => \$port,
) or pod2usage(2);

pod2usage(1) if $help;
pod2usage( -exitval => 0, -verbose => 2 ) if $man;
pod2usage( -msg => 'No database specified', -exitval => 2) unless $db;

#=================
# Main 
#=================

say STDERR "Processing $db" if $verbose;

# Setup database connection.
my $dsn = "dbi:Pg:database=$db;host=$host;port=$port";
my $dbh = DBI->connect($dsn, $username, $password);
$dbh->{AutoCommit} = 0;
$dbh->{RaiseError} = 1;
$dbh->{PrintError} = ($verbose == 1) ? 1 : 0;

# Download files if needed.  The -N will examine timestamps and only 
# fetch if the remote file has been updated.
system('wget -N ftp://ftp.expasy.org/databases/enzyme/enzyme.dat');
system('wget -N ftp://ftp.expasy.org/databases/enzyme/enzclass.txt');

# Regex for filtering out transferred or deleted entries.
my $transf_deleted_regex = qr/^(Transferred|Deleted) entry/;

# Setup Enzyme file objects.
my $enzyme_dat_file   = path('enzyme.dat');
my $enzyme_class_file = path('enzclass.txt');

# Parse Enzyme flat files and load into a hashref for lookups.
my $enzyme_db       = process_enzyme_dat({ files => [$enzyme_dat_file], fields => ['ID','DE','CA'] });
my $enzyme_class_db = process_enzyme_class({ files => [$enzyme_class_file] });

# Read in the query that fetches all EC numbers.
my $ec_num_query = path('ec_num_query.sql')->slurp_utf8;

# Checks for the required dbxrefprop types and inserts them.
my $cvterm_ids = setup_proptypes({ dbh => $dbh, proptypes => $ec_proptypes });

# Fetch the results from the EC query.
my $ec_results = $dbh->selectall_arrayref($ec_num_query, { Slice => {} });

# Sets the number of '?' placeholders to the number of elements
# in the dbxrefprop type hash.
my $bind_placeholder = join(',', ('?') x values %{$cvterm_ids});
# Delete existing dbxrefprops.
$dbh->do("delete from dbxrefprop where type_id in ($bind_placeholder)", {}, (values %{$cvterm_ids}));

# Loop over each result.
foreach my $result ( @$ec_results ) {
  my $ecnum     = $result->{ec};        # EC number from Chado.
  my $dbxref_id = $result->{dbxref_id}; # Corresponding dbxref_id
  my $alt_ecnum = $ecnum . '.-';        # Alternate EC number to correct for errors in Chado data from GO.

  my $entry = $enzyme_db->{$ecnum};

  if ($entry) {
    # Skip deleted or transferred entries.
    next if ($entry->{DE} && grep { $_ =~ $transf_deleted_regex } @{$entry->{DE}});

    # Iterate over the fields extracted from the enzyme.dat file
    for my $field (sort { $a cmp $b } keys %{$entry}) {
      # Some fields are multivalued so we fetch them as an array.
      my @values = @{$entry->{$field}};
      # Insert the dbxreprop for each value.
      for (my $i=0; $i < scalar @values; $i++) {
        insert_dbxrefprop({
            dbh       => $dbh,
            dbxref_id => $dbxref_id, 
            cvterm_id => $cvterm_ids->{$field},
            value     => $values[$i],
            rank      => $i
          });
      }
    }
  }
  # Insert the dbxrefprop for the Enzyme class
  elsif ($enzyme_class_db->{$ecnum}) {
    insert_dbxrefprop({
        dbh       => $dbh,
        dbxref_id => $dbxref_id, 
        cvterm_id => $cvterm_ids->{class},
        value     => $enzyme_class_db->{$ecnum},
        rank      => 0
      });
  }
  # Sometimes Chado uses a class ID without a '.-' at the end
  # so we look for that variant and insert the dbxrefprop.
  elsif ($enzyme_class_db->{$alt_ecnum}) {
    insert_dbxrefprop({
        dbh       => $dbh,
        dbxref_id => $dbxref_id, 
        cvterm_id => $cvterm_ids->{class},
        value     => $enzyme_class_db->{$alt_ecnum},
        rank      => 0
      });
  }
  else {
    say STDERR "ERROR: $ecnum found in Chado but not in data files. Ignoring...";
  }
}

# Commit all inserts.
$dbh->commit;

#==============
# End of main
#============== 

# Function to insert dbxrefprop's for the Enzyme metadata.
sub insert_dbxrefprop {
  my ($args) = @_;

  my $dbh       = $args->{dbh};       # Database handle to use.
  my $dbxref_id = $args->{dbxref_id}; # dbxref_id of the EC number.
  my $cvterm_id = $args->{cvterm_id}; # cvterm_id to use for the dbxrefprop.type_id column.
  my $value     = $args->{value};     # The field value.
  my $rank      = $args->{rank};      # Rank, non-zero for multi-values fields.

  try {
    $dbh->do('insert into dbxrefprop (dbxref_id, type_id, value, rank) values (?, ?, ?, ?)',{},($dbxref_id, $cvterm_id, $value, $rank));
  } catch {
    warn $_;
    $dbh->rollback;
  }
}


# Function to parse the Enzyme class file.
sub process_enzyme_class {
  my ($args) = @_;

  my $result = {};

  my $ec_class_regex = qr/^(\d.*?\.\-)\s+(.*)$/;

  # Loop over all files.
  for my $file (@{$args->{files}}) {
    say STDERR "Working on $file" if $verbose;
    my $fh = $file->openr_utf8;

    # Loop over each line of the file.
    while (<$fh>) {
      chomp;
      if ($_ =~ $ec_class_regex) {
        my ($id, $name) = ($1, $2);
        # Remove the extra spaces from the EC class ID
        $id =~ s/\s+//g;
        $result->{$id} = $name;
      }
    }
    close($fh);
  }
  return $result;
}

# Function to parse the Enzyme.dat file.
sub process_enzyme_dat {
  my ($args) = @_;

  my $result = {};

  # Construct a regex to extract the fields we need.
  my $wanted_fields = join('|',@{$args->{fields}});
  my $field_regex = qr/^($wanted_fields)\s+(.*)$/;

  # Loop over all files.
  for my $file (@{$args->{files}}) {
    say STDERR "Working on $file" if $verbose;
    my $fh = $file->openr_utf8;
    my $curr_id;

    # Loop over each line of the file.
    while (<$fh>) {
      chomp;

      # See if the line matches the requested field.
      if ($_ =~ $field_regex) {
        # Store the ID of the record.
        if ($1 eq "ID") {
          $curr_id = $2;
          $result->{$curr_id} = {};
        }
        # Store all other fields under this ID.
        else {
          my $field = $1;
          my $val   = $2;
          my $vals = $result->{$curr_id}{$field} // [];
          push(@{$vals},$val);
          $result->{$curr_id}{$field} = $vals;
        }
      }
    }
    close($fh);
  }

  # Stitch multi line catalytic activities back together.
  for my $id (keys %{$result}) {
    my $ca = $result->{$id}{'CA'};
    # Only fix CA fields that have more than one CA.
    if ($ca && scalar @{$ca} > 1) {
      my $all_ca = join(' ',@{$ca});
      # Use positive lookbehind to split on all
      # zero length strings that are preceded by a period '.'.
      # This essentially splits each reaction on '.'
      # without throwing the '.' away.
      my @split_cas = split(/(?<=\.)\s*/,$all_ca);
      # Replace the old CA with the stitched CA.
      $result->{$id}{'CA'} = \@split_cas;
    }
  }

  return $result;
}

# Checks to see if the Chado instance already has the required prop types
# for the dbxrefprop entries.  It sets them up if not.
sub setup_proptypes {
  my ($args) = @_;
  my $dbh = $args->{dbh};
  my $proptypes = $args->{proptypes};

  my $query =<<'SQL';
select cvterm_id
  from cvterm cvt join cv on (cvt.cv_id=cv.cv_id)
  where cv.name = 'dbxrefprop type'
    and cvt.name = ?
;
SQL

  my $result;

  for my $prop (keys %{$proptypes}) {
    # Get the full property type name.
    my $name = $proptypes->{$prop};
    # See if it exists already.
    my $cvterm_id = $dbh->selectrow_array($query,{},$name);
    # If not, make it.
    if (!$cvterm_id) {
      # Insert new cvterm and get its ID.
      insert_proptype({ dbh => $dbh, prop => $name });
      $cvterm_id = $dbh->selectrow_array($query,{},$name);
    }
    # Keep track of the cvterm_id.
    $result->{$prop} = $cvterm_id;
  }
  # Return a hash of the field name (e.g. DE, CA, class) and the cvterm_id assigned to it.
  return $result;
}

# Inserts a given property type for the dbxrefprop entries use for
# the EC dbxref.
sub insert_proptype {
  my ($args) = @_;
  my $dbh = $args->{dbh};   # DB handle
  my $prop = $args->{prop}; # The EC prop to setup.

  try {
    # Get the db.db_id and cv.cv_id columns for the prop we are trying to create.
    my ($db_id) = $dbh->selectrow_array("select db_id from db where name = 'FlyBase_reporting'");
    my ($cv_id) = $dbh->selectrow_array("select cv_id from cv where name = 'dbxrefprop type'");

    # Setup dbxref entry for cvterm and get the dbxref_id;
    my $acc = "dbxrefprop type:$prop";
    $dbh->do("insert into dbxref (db_id,accession) values (?,?)",{},($db_id,$acc));
    my ($dbxref_id) = $dbh->selectrow_array("select dbxref_id from dbxref where db_id = ? and accession = ?;", {}, ($db_id, $acc));

    # Insert the cvterm for the dbxrefprop to be used later on.
    $dbh->do("insert into cvterm (cv_id, dbxref_id, is_obsolete, is_relationshiptype, name) values (?, ?, 0, 0, ?)", {}, ($cv_id, $dbxref_id, $prop));
  } catch {
    warn $_;
    $dbh->rollback;
  };
}
