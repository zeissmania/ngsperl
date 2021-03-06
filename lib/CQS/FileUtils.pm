package CQS::FileUtils;

use strict;
use warnings;

use CQS::CQSDebug;

require Exporter;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = ( 'all' => [qw( list_directories list_files has_file create_directory_or_die change_extension change_extension_gzipped file_exists check_file_exists_command)] );

our @EXPORT = ( @{ $EXPORT_TAGS{'all'} } );

our $VERSION = '0.01';

sub change_extension {
  my ( $filename, $newextension ) = @_;
  $filename =~ s{\.[^.]*$}{$newextension};
  return ($filename);
}

sub change_extension_gzipped {
  my ( $filename, $newextension ) = @_;
  if ( $filename =~ /.gz$/ ) {
    $filename = change_extension( $filename, "" );
  }

  $filename = change_extension( $filename, $newextension );
  return ($filename);
}

sub list_directories {
  my $root = shift;
  my @result;

  opendir my ($dh), $root or die "Couldn't open dir '$root': $!";
  my @links = readdir $dh;
  closedir $dh;

  foreach my $link (@links) {
    if ( ( $link eq "." ) || ( $link eq ".." ) ) {
      next;
    }

    my $reallink = $root . "/" . $link;
    if ( -d $reallink ) {
      push( @result, $link );
    }
  }

  return @result;
}

sub list_files {
  my ( $root, $filter ) = @_;
  my @result;

  opendir my ($dh), $root or die "Couldn't open dir '$root': $!";
  my @links = readdir $dh;
  closedir $dh;

  foreach my $link (@links) {
    if ( ( $link eq "." ) || ( $link eq ".." ) ) {
      next;
    }

    my $reallink = $root . "/" . $link;
    if ( ( -f $reallink ) && ( !defined($filter) || $filter->($reallink) ) ) {
      push( @result, $link );
    }
  }

  return @result;
}

sub has_file {
  my ( $dir, $filter ) = @_;
  my @result;

  opendir my ($dh), $dir or die "Couldn't open dir '$dir': $!";
  my @links = readdir $dh;
  closedir $dh;

  foreach my $link (@links) {
    if ( ( $link eq "." ) || ( $link eq ".." ) ) {
      next;
    }

    my $reallink = $dir . "/" . $link;
    if ( ( -f $reallink ) && ( !defined($filter) || $filter->($link) ) ) {
      return (1);
    }
  }

  return (0);
}

sub create_directory_or_die {
  my ($result) = @_;
  unless ( -e $result or mkdir($result) ) {
    if ( !is_debug() ) {
      die "Cannot create directory $result\n";
    }
  }
  return ($result);
}

sub file_exists {
  my $file   = shift;
  my $result = 0;
  if ( defined($file) ) {
    $result = -e $file;
  }
  return ($result);
}

sub check_file_exists_command {
  my @files   = @_;
  my $result = "";
  for my $file (@files){
    $result = $result . "if [ ! -e $file ]; then 
  echo file not exists : $file, task failed.
  exit 1
fi
"
  }
  
  return $result;
}

1;
