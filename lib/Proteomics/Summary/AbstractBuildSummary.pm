#!/usr/bin/perl
package Proteomics::Summary::AbstractBuildSummary;

use strict;
use warnings;
use File::Basename;
use File::Slurp;
use CQS::PBS;
use CQS::ConfigUtils;
use CQS::SystemUtils;
use CQS::FileUtils;
use CQS::UniqueTask;
use CQS::StringUtils;

our @ISA = qw(CQS::UniqueTask);

sub new {
  my ($class) = @_;
  my $self = $class->SUPER::new();
  $self->{_name}   = __PACKAGE__;
  $self->{_suffix} = "_abs";
  bless $self, $class;
  return $self;
}

sub get_datasets {
  my ( $self, $config, $section ) = @_;

  my %raw_files = %{ get_raw_files( $config, $section ) };
  my %datasets;
  if ( has_raw_files( $config, $section, "datasets" ) ) {
    my %dss = %{ get_raw_files( $config, $section, "datasets" ) };
    foreach my $dsName ( sort keys %dss ) {
      my @sample_names = @{ $dss{$dsName} };
      my @samples     = ();
      foreach my $sample_name (@sample_names) {
        if ( defined $raw_files{$sample_name} ) {
          push( @samples, @{ $raw_files{$sample_name} } );
        }
      }
      if ( scalar(@samples) > 0 ) {
        $datasets{$dsName} = \@samples;
      }
    }
  }
  else {
    %datasets = %raw_files;
  }

  my $parameterFile = get_param_file( $config->{$section}{parameter_file}, "parameter_file", 1 );
  my @lines = read_file( $parameterFile, chomp => 1 );

  my @dataset   = ();
  my $indataset = 0;
  for ( my $index = 0 ; $index < scalar(@lines) ; $index++ ) {
    $lines[$index] =~ s/\r//g;
    if ( $lines[$index] =~ "<Dataset>" ) {
      $indataset = 1;
    }
    elsif ( $lines[$index] =~ "</Dataset>" ) {
      $indataset = 0;
    }
    elsif ( !$indataset ) {
      next;
    }
    elsif ( $lines[$index] =~ "PathName" ) {
      next;
    }
    elsif ( $lines[$index] =~ "<Name>" ) {
      next;
    }
    else {
      push( @dataset, $lines[$index] );
    }
  }

  return ( \%datasets, \@lines, \@dataset );
}

1;
