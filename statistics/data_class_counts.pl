#!/usr/bin/env perl
use strict;
use warnings;

use 5.010;

use DBI;
use POSIX qw/cuserid/;
use Getopt::Long;
use Pod::Usage;

=pod

=head1 NAME

data_class_counts.pl - A script to calculate counts of FlyBase data classes.

=head1 SYNOPSIS

 data_class_counts.pl [options]

 Options:
 --database One or more databases to query.
 --hostname The database hostname
 --username The database user
 --password The database user password
 --port     The database port
 --help     Print a help message
 --verbose Print extra information to STDERR
 --man Show a man page help doc.
    
see L<Options> for full details.

 e.g.
 ./data_class_counts.pl --database FB2015_04
 ./data_class_counts.pl --database FB2015_04 --database FB2015_03
 ./data_class_counts.pl --hostname myserver.com --username johnsmith --password mypassword --database FB2015_03

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

 Copyright (c) 2015, Indiana University & FlyBase 
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

my $verbose     = 0;
my $help      = 0;
my $man       = 0;
my $host      = 'localhost';
my $username  = cuserid();
my $password  = '';
my $port      = 5432;
my $species;
my @databases = ();

my $getopt = GetOptions(
    'help|?'            => \$help,
    'verbose|v'         => \$verbose,
    'man'               => \$man,
    'hostname|host=s'   => \$host,
    'username|user=s'   => \$username,
    'password|passwd=s' => \$password,
    'database|db=s'     => \@databases,
    #'species=s'         => \$species,
    'port=i'            => \$port
) or pod2usage(2);

pod2usage(1) if $help;
pod2usage( -exitval => 0, -verbose => 2 ) if $man;
pod2usage( -msg => 'No database specified', -exitval => 2) if scalar @databases == 0;

my %result;

@databases = map { split /,/ } @databases;

for my $db (@databases) {
    say STDERR "Processing $db" if $verbose;

    my $dsn = "dbi:Pg:database=$db;host=$host;port=$port";
    my $opts = ($verbose == 1) ? { RaiseError => 0, PrintError => 1 } : { RaiseError => 0, PrintError => 0};
    my $dbh = DBI->connect($dsn, $username, $password, $opts);

    #Get counts from the feature table in one go.
    my $counts = feature_table({ dbh => $dbh });
    for my $dc (keys %{$counts}) {
        $result{$dc}{$db} = $counts->{$dc};
    }

    my $dmel_fbgn_query =<<'SQL';
select count(*)
    from feature f join organism o on (f.organism_id=o.organism_id)
    where f.uniquename ~ E'^FBgn\\d+$'
      and f.is_obsolete = false
      and f.is_analysis = false
      and o.genus='Drosophila'
      and o.species='melanogaster';
SQL

    $result{'FBgn_Dmel'}{$db} = get_count({dbh => $dbh, query => $dmel_fbgn_query});
    $result{'FBsn'}{$db} = get_count({ dbh => $dbh, bind => ['^FBsn\\d+$'], query => "select count(*) from strain where uniquename ~ ? and is_obsolete=false"});
    $result{'FBtc'}{$db} = get_count({ dbh => $dbh, bind => ['^FBtc\\d+$'], query => "select count(*) from cell_line where uniquename ~ ?"});
    $result{'FBgg'}{$db} = get_count({ dbh => $dbh, bind => ['^FBgg\\d+$'], query => "select count(*) from grp where uniquename ~ ? and is_analysis=false and is_obsolete=false"});
    $result{'FBig'}{$db} = get_count({ dbh => $dbh, bind => ['^FBig\\d+$'], query => "select count(*) from interaction_group where uniquename ~ ? and is_obsolete=false"});
    $result{'FBlc'}{$db} = get_count({ dbh => $dbh, bind => ['^FBlc\\d+$'], query => "select count(*) from library where uniquename ~ ? and is_obsolete=false"});
    $result{'FBst'}{$db} = get_count({ dbh => $dbh, bind => ['^FBst\\d+$'], query => "select count(*) from stock where uniquename ~ ? and is_obsolete=false"});
    $result{'FBrf'}{$db} = get_count({ dbh => $dbh, bind => ['^FBrf\\d+$'], query => "select count(*) from pub where uniquename ~ ? and is_obsolete=false"});
    $result{'FBhh'}{$db} = get_count({ dbh => $dbh, bind => ['^FBhh\\d+$'], query => "select count(*) from humanhealth where uniquename ~ ? and is_obsolete=false"});
    $dbh->disconnect;
}

printf "%-10s\t",'#Data Class';
for (@databases) {
    printf "%20s\t", $_;
}
print "\n";

for my $dc (keys %result) {
    printf "%-10s\t", $dc;
    for my $db (@databases) {
        printf "%20s\t", $result{$dc}{$db} || 0;
    }
    print "\n";
}

sub get_count {
    my ($args) = @_;
    my $ary_ref = $args->{dbh}->selectall_arrayref($args->{query},{},@{$args->{bind}});
    return $ary_ref->[0]->[0] || 0;
}

sub feature_table {
    my ($args) = @_;

    my $query =<<'SQL';
select substring(f.uniquename from 1 for 4) as data_class, count(*) as count
    from feature f
    where f.uniquename ~ E'^FB\\w{2}[0-9]+$'
      and f.uniquename !~ '^FB(og|bs|ri|X0|XO)'
      and f.is_obsolete = false
      and f.is_analysis = false
    group by data_class;
SQL
    my $ary_ref = $args->{dbh}->selectall_arrayref($query);
    return { map { $_->[0] => $_->[1] } @{$ary_ref} };
}


