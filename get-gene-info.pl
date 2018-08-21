#!/usr/bin/env perl

use strict;
use warnings;

IDConverter->new()->convert();

{
  package IDConverter;
  use lib qw(./lib/perl5);
  use Getopt::Long qw(GetOptions);
  use Pod::Usage qw(pod2usage);
  use HTTP::Tiny;
  use JSON qw(decode_json);
  use Encode;
  use Data::Dumper;
  use Parallel::ForkManager 0.7.6;

  sub new {
    my $class = shift;
    my $self = {};
    $self->{_server} = 'https://rest.genenames.org';
    my $man = 0;
    my $help = 0;
    my $type = '';
    my $file = '';
    $self->{columns} = [];

    GetOptions(
      'help|?' => \$help,
      'man' => \$man,
      'type=s' => \$type,
      'file=s' => \$file,
      "column=s" => $self->{columns}
    ) or pod2usage(1);
    pod2usage(-exitval => 0) if $help;
    pod2usage({-verbose => 2, -exitval => 0}) if $man;
    $self->{file} = $file;
    $self->{type} = $type;
    $self->{column_index} = get_column_index($self->{_server});
    test_args($type, $file, $self->{columns});
    $self->{ids} = check_ids($type, $file);
    return bless $self, $class;;
  }

  sub convert {
    my $self = shift;
    my $type_convert =  {
      ncbi    => 'entrez_id',
      hgnc    => 'hgnc_id',
      ensembl => 'ensembl_gene_id',
      symbol  => 'symbol'
    };
    my $http = HTTP::Tiny->new();
    my $pm = Parallel::ForkManager->new(10, 'tmp/');

    # data structure retrieval and handling
    $pm->run_on_finish ( # called BEFORE the first call to start()
      sub {
        my ($pid, $exit_code, $ident, $exit_signal, $core_dump, $data_structure_reference) = @_;

        # retrieve data structure from child
        if (defined($data_structure_reference)) {  # children are not forced to send anything
          my $string = ${$data_structure_reference};  # child passed a string reference
          print "$string\n";
        }
        else {  # problems occurring during storage or retrieval will throw a warning
          print qq|No message received from child process $pid!\n|;
        }
      }
    );


    # run the parallel processes
    IDS:
    foreach my $id (@{$self->{ids}}){
      $pm->start() and next IDS;

      # generate a random statement about food preferences
      my $q_type = $type_convert->{ $self->{type} };
      my $query = qq{/$q_type/$id};
      my $response = $http->get($self->{_server}.'/fetch'.$query, {
        headers => { 'Accept' => 'application/json' }
      });
      die "Failed!\n" if $response->{status} ne '200';
      my $json_bytes = encode('UTF-8', $response->{content});
      my $result = decode_json($json_bytes);
      my $record = $result->{response}->{docs}->[0];
      my $line = $self->tabulate($record);

      # send it back to the parent process
      $pm->finish(0, \$line);  # note that it's a scalar REFERENCE, not the scalar itself
    }
    $pm->wait_all_children;
  }

  sub tabulate {
    my $self = shift;
    my $record = shift;
    my @line;
    foreach my $col (@{$self->{columns}}){
      if($record->{$col}){
        if(ref($record->{$col}) eq 'ARRAY'){
          push @line, join ',', map {qq("$_")} @{$record->{$col}};
        } else {
          push @line, sprintf q("%s"), $record->{$col};
        }
      } else {
        push @line, '';
      }
    }
    return join "\t", @line;
  }
  

  # class methods
  sub get_column_index {
    my $server = shift;
    my $http = HTTP::Tiny->new();
    my $response = $http->get($server.'/info', {
      headers => { 'Accept' => 'application/json' }
    });
    die "Failed!\n" if $response->{status} ne '200';
    my $json_bytes = encode('UTF-8', $response->{content});
    my $result = decode_json($json_bytes);
    my %hash = map { $_ => 1 } @{$result->{storedFields}};
    return \%hash;
  }

  sub check_ids {
    my ($type, $file) = @_;
    my @ids;
    my $dispatch_t =  {
      ncbi    => \&is_ncbi_id,
      hgnc    => \&is_hgnc_id,
      ensembl => \&is_ensembl_id,
      symbol => \&is_approved_symbol
    };
    my $line_num = 1;
    open my $fh, '<', $file or die "Cannot read file $file";
    while(my $id = <$fh>){
      chomp $id;
      die "'$id' is not of type '$type' on line $line_num of the file '$file'" unless($dispatch_t->{$type}->($id));
      $line_num++;
      push @ids, $id;
    }
    close $fh or die "Cannot close file $file";
    return \@ids;
  }

  sub is_hgnc_id {
    my $id = shift;
    return 0 if($id !~ m/^HGNC:\d+$/);
    return 1;
  }

  sub is_approved_symbol {
    my $id = shift;
    return 0 if($id !~ m/^[A-Z]{1}[A-Z0-9\-@_]+$/);
    return 1;
  }

  sub is_ncbi_id {
    my $id = shift;
    return 0 if($id !~ m/^\d+$/);
    return 1;
  }

  sub is_ensembl_id {
    my $id = shift;
    return 0 if($id !~ m/^ENSG\d{11}$/);
    return 1;
  }

  sub test_args {
    my ($type, $file, $columns) = @_;
    my $err = '';
    $err .= test_type($type);
    $err .= test_file($file);
    $err .= test_columns($columns);

    pod2usage({-exitval => 1, -verbose => 0, -message => $err}) if $err;
  }

  sub test_columns {
    my $columns = shift;
    my $http = HTTP::Tiny->new();
    my $response = $http->get('https://rest.genenames.org/info', {
      headers => { 'Accept' => 'application/json' }
    });
    die "Failed!\n" if $response->{status} ne '200';
    my $json_bytes = encode('UTF-8', $response->{content});
    my $result = decode_json($json_bytes);
    my %hash = map { $_ => 1 } @{$result->{storedFields}};
    my $err = '';
    foreach my $col (@$columns){
      $err .= "Unknown column: $col\n" unless ($hash{$col});
    }
    return $err;
  }

  sub test_file {
    my $file = shift;
    my $err = '';
    if(! $file){
      $err .= qq{The argument 'file' is missing\n};
    } else {
      unless(-s $file){
        $err .= qq{The file '$file' does not exist\n};
      }
      elsif(! -r $file){
        $err .= qq{The file '$file' is not readable\n};
      }
    }
    return $err;
  }

  sub test_type {
    my $type = shift;
    my $err = '';
    if(! $type){
      $err .= qq{The argument 'type' is missing\n};
    } else {
      if($type !~ m/^ncbi|hgnc|ensembl|symbol$/){
        $err .= qq{the argument 'type' must be either 'ncbi', 'hgnc', 'symbol' or 'ensembl'\n};
      }
    }
    return $err;
  }
}

__END__

=head1 NAME

get-gene-info: Retrieving HGNC gene symbol reports (human genes only)
via a list of gene IDs

=head1 SYNOPSIS

./get-gene-info.pl -type=ncbi -file=ids.txt -column=hgnc_id -column=symbol

  Options:
    -help            Brief help message.
    -man             Full documentation.
    -type            Gene ID type within the file.
    -file            File name containing the list of gene IDs.
    -column          This argument can be used multiple times. Will
                     retrieve the columns specified from the gene report.

=head1 DESCRIPTION

A perl script which will return JSON objects containing HGNC gene
information for each gene ID specified in the user provided file.
The script utilises the HGNC REST service and allows the user to retrieve
any data that is displayed within our gene symbol reports.

=head1 OPTIONS

=over 4

=item B<-help>

Print a brief help message and exits.

=item B<-man>

Prints the manual page and exits.

=item B<-type>

The type of gene IDs found within the provided file. Type can be one of the following:

    ncbi               for NCBI gene IDs eg. 673
    hgnc               for HGNC gene IDs eg. HGNC:1097
    ensembl            for ensembl gene IDs eg. ENSG00000157764
    symbol             for HGNC approved symbol eg. TP53

=item B<-file>

The path of the txt file that contains a list of gene IDs of the type seen above

=item B<-column>

Use this flag for each column you want to appear within the output.
Columns will be tab separated. For a list of columns that you can use please
refer to either our REST help page https://www.genenames.org/help/rest-web-service-help#Stored_fields
or use the following REST service command http://rest.genenames.org/info and use any
column under "storedFields".

=back

=cut