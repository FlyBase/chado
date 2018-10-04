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

extend_ec_data.pl - Extends associated Enzyme Commission (EC) data in Chado.

=head1 SYNOPSIS

 extend_ec_data.pl [options]

 Options:
 --database The database to query.
 --hostname The database hostname
 --username The database user
 --password The database user password
 --port     The database port
 --force
 --help     Print a help message
 --verbose Print extra information to STDERR
 --man Show a man page help doc.
    
see L<Options> for full details.

 e.g.
 ./extend_ec_data.pl --database FB2015_04
 ./extend_ec_data.pl --database FB2015_04 --database FB2015_03
 ./extend_ec_data.pl --hostname myserver.com --username johnsmith --password mypassword --database FB2015_03

=head1 DESCRIPTION


=head2 Options

=over 5

=item --database <database name>

The database name to connect to.  Multiple databases can be specified
by repeating the flag or using a comma delimited list of names.

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
my $force        = 0;

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
    'force'             => \$force,
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
system('wget -N http://ftp.ebi.ac.uk/pub/databases/enzyme/enzyme.dat');
system('wget -N http://ftp.ebi.ac.uk/pub/databases/enzyme/enzclass.txt');

my $transf_deleted_regex = qr/^(Transferred|Deleted) entry/;

my $enzyme_dat_file   = path('enzyme.dat');
my $enzyme_class_file = path('enzclass.txt');

my $enzyme_db       = process_enzyme_dat({ files => [$enzyme_dat_file], fields => ['ID','DE','CA'] });
my $enzyme_class_db = process_enzyme_class({ files => [$enzyme_class_file] });

my $ec_num_query = path('ec_num_query.sql')->slurp_utf8;

my $cvterm_ids = setup_proptypes({ dbh => $dbh, proptypes => $ec_proptypes });

my $ec_results = $dbh->selectall_arrayref($ec_num_query, { Slice => {} });

foreach my $result ( @$ec_results ) {
  my $ecnum     = $result->{ec};
  my $dbxref_id = $result->{dbxref_id};
  my $alt_ecnum = $ecnum . '.-';

  if ($enzyme_db->{$ecnum}) {
    my $entry = $enzyme_db->{$ecnum};
    
    # Skip deleted or transferred entries.
    next if ($entry->{DE} && grep { $_ =~ $transf_deleted_regex } @{$entry->{DE}});

    for my $field (sort { $a cmp $b } keys %{$entry}) {
      my @values = @{$entry->{$field}};
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
  elsif ($enzyme_class_db->{$ecnum}) {
    insert_dbxrefprop({
        dbh       => $dbh,
        dbxref_id => $dbxref_id, 
        cvterm_id => $cvterm_ids->{class},
        value     => $enzyme_class_db->{$ecnum},
        rank      => 0
      });
  }
  # Sometimes Chado uses a class ID without a '.-';
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

# Committ all inserts.
$dbh->commit;

#==============
# End of main
#============== 

sub insert_dbxrefprop {
  my ($args) = @_;

  my $dbh       = $args->{dbh};
  my $dbxref_id = $args->{dbxref_id};
  my $cvterm_id = $args->{cvterm_id};
  my $value     = $args->{value};
  my $rank      = $args->{rank};

  try {
    $dbh->do('insert into dbxrefprop (dbxref_id, type_id, value, rank) values (?, ?, ?, ?)',{},($dbxref_id, $cvterm_id, $value, $rank));
  } catch {
    warn $_;
    $dbh->rollback;
  }
}


sub process_enzyme_class {
  my ($args) = @_;

  my $result = {};

  my $ec_class_regex = qr/^(\d.*?\.\-)\s+(.*)$/;

  # Loop over all files.
  for my $file (@{$args->{files}}) {
    say STDERR "Working on $file";
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

sub process_enzyme_dat {
  my ($args) = @_;

  my $result = {};

  # Construct a regex to extract the fields we need.
  my $wanted_fields = join('|',@{$args->{fields}});
  my $field_regex = qr/^($wanted_fields)\s+(.*)$/;

  # Loop over all files.
  for my $file (@{$args->{files}}) {
    say STDERR "Working on $file";
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
  where cv.name = 'property type'
    and cvt.name = ?
;
SQL

  my $result;

  for my $prop (keys %{$proptypes}) {
    my $name = $proptypes->{$prop};
    my $cvterm_id = $dbh->selectrow_array($query,{},$name);
    if (!$cvterm_id) {
      # Insert new cvterm and get its ID.
      insert_proptype({ dbh => $dbh, prop => $name });
      $cvterm_id = $dbh->selectrow_array($query,{},$name);
    }
    $result->{$prop} = $cvterm_id;
  }
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
    my ($cv_id) = $dbh->selectrow_array("select cv_id from cv where name = 'property type'");

    # Setup dbxref entry for cvterm and get the dbxref_id;
    my $acc = "property type:$prop";
    $dbh->do("insert into dbxref (db_id,accession) values (?,?)",{},($db_id,$acc));
    my ($dbxref_id) = $dbh->selectrow_array("select dbxref_id from dbxref where db_id = ? and accession = ?;", {}, ($db_id, $acc));

    # Insert the cvterm for the dbxrefprop to be used later on.
    $dbh->do("insert into cvterm (cv_id, dbxref_id, is_obsolete, is_relationshiptype, name) values (?, ?, 0, 0, ?)", {}, ($cv_id, $dbxref_id, $prop));
  } catch {
    warn $_;
    $dbh->rollback;
  };
}
