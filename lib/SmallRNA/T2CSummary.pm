#!/usr/bin/perl
package SmallRNA::T2CSummary;

use strict;
use warnings;
use File::Basename;
use CQS::PBS;
use CQS::ConfigUtils;
use CQS::SystemUtils;
use CQS::FileUtils;
use CQS::NGSCommon;
use CQS::StringUtils;
use CQS::UniqueTask;

our @ISA = qw(CQS::UniqueTask);

sub new {
  my ($class) = @_;
  my $self = $class->SUPER::new();
  $self->{_name}   = __PACKAGE__;
  $self->{_suffix} = "_t2c";
  bless $self, $class;
  return $self;
}

sub perform {
  my ( $self, $config, $section ) = @_;

  my ( $task_name, $path_file, $pbs_desc, $target_dir, $log_dir, $pbs_dir, $result_dir, $option, $sh_direct, $cluster ) = get_parameter( $config, $section );

  my $cqstools = get_cqstools( $config, $section, 1 );

  my %raw_files = %{ get_raw_files( $config, $section ) };

  my $filelist = $self->get_file( $pbs_dir, ${task_name}, ".filelist", 0 );
  open( FL, ">$filelist" ) or die "Cannot create $filelist";
  for my $sample_name ( sort keys %raw_files ) {
    my @count_files = @{ $raw_files{$sample_name} };
    my $countFile  = $count_files[0];
    print FL $sample_name, "\t", $countFile, "\n";
  }
  close(FL);

  my $pbs_file  = $self->get_pbs_filename( $pbs_dir, $task_name );
  my $pbs_name  = basename($pbs_file);
  my $log      = $self->get_log_filename( $log_dir, $task_name );
  my $log_desc = $cluster->get_log_description($log);

  my $outputfile = $self->get_file( $result_dir, ${task_name}, "_t2c.tsv", 0 );
  my $outputname = basename($outputfile);

  open( my $out, ">$pbs_file" ) or die $!;
  print $out "$pbs_desc
$log_desc

$path_file

cd $result_dir

if [ -s $outputname ]; then
  echo job has already been done. if you want to do again, delete $outputfile and submit job again.
  exit 0;
fi

echo T2CSummary=`date`

mono $cqstools smallrna_t2c_summary $option -o $outputname -l $filelist

echo T2CSummary_finished
";
  close $out;

  print "!!!shell file $pbs_file created.\n";
}

sub result {
  my ( $self, $config, $section, $pattern ) = @_;
  my ( $task_name, $path_file, $pbs_desc, $target_dir, $log_dir, $pbs_dir, $result_dir, $option, $sh_direct ) = get_parameter( $config, $section );

  my $result = {};

  my @result_files = ();
  my $outputfile  = $self->get_file( $result_dir, ${task_name}, "_t2c.tsv", 0 );
  my $filelist    = $self->get_file( $pbs_dir, ${task_name}, ".filelist", 0 );
  push( @result_files, $outputfile );
  push( @result_files, $filelist );
  $result->{$task_name} = filter_array( \@result_files, $pattern );

  return $result;
}

1;
