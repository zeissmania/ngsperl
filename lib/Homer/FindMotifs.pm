#!/usr/bin/perl
package Homer::FindMotifs;

use strict;
use warnings;
use File::Basename;
use CQS::PBS;
use CQS::ConfigUtils;
use CQS::SystemUtils;
use CQS::FileUtils;
use CQS::Task;
use CQS::NGSCommon;
use CQS::StringUtils;

our @ISA = qw(CQS::Task);

sub new {
  my ($class) = @_;
  my $self = $class->SUPER::new();
  $self->{_name}   = __PACKAGE__;
  $self->{_suffix} = "_fm";
  bless $self, $class;
  return $self;
}

sub perform {
  my ( $self, $config, $section ) = @_;

  my ( $task_name, $path_file, $pbs_desc, $target_dir, $log_dir, $pbs_dir, $result_dir, $option, $sh_direct, $cluster, $thread ) = get_parameter( $config, $section );

  my %tagDirectories = %{ get_raw_files( $config, $section ) };

  my $rawFiles = get_raw_files( $config, $section );
  my $genome = get_option( $config, $section, "homer_genome" );

  my $shfile = $self->get_task_filename( $pbs_dir, $task_name );
  open( my $sh, ">$shfile" ) or die "Cannot create $shfile";
  print $sh get_run_command($sh_direct);

  for my $pairName ( sort keys %$rawFiles ) {
    my $files = $rawFiles->{$pairName};
    my $cur_dir  = create_directory_or_die( $result_dir . "/$pairName" );

    my $pbs_file = $self->get_pbs_filename( $pbs_dir, $pairName );
    my $pbs_name = basename($pbs_file);
    my $log      = $self->get_log_filename( $log_dir, $pairName );
    my $log_desc = $cluster->get_log_description($log);

    my $pbs = $self->open_pbs( $pbs_file, $pbs_desc, $log_desc, $path_file, $cur_dir );
    for my $file (@$files) {
      my $output    = basename($file);
      my $finalFile = "${output}/homerResults.html";
      print $pbs "if [ ! -s $finalFile ]; then
  findMotifsGenome.pl $file $genome $output/ $option 
fi

";
    }
    $self->close_pbs( $pbs, $pbs_file );

    print $sh "\$MYCMD ./$pbs_name \n";
  }
  print $sh "exit 0\n";
  close $sh;

  if ( is_linux() ) {
    chmod 0755, $shfile;
  }

  print "!!!shell file $shfile created, you can run this shell file to submit all tasks.\n";
}

sub result {
  my ( $self, $config, $section, $pattern ) = @_;

  my ( $task_name, $path_file, $pbs_desc, $target_dir, $log_dir, $pbs_dir, $result_dir, $option, $sh_direct ) = get_parameter( $config, $section, 0 );

  my $rawFiles = get_raw_files( $config, $section );

  my $result = {};
  for my $pairName ( sort keys %$rawFiles ) {
    my $files        = $rawFiles->{$pairName};
    my @result_files = ();
    for my $file (@$files) {
      my $output    = basename($file);
      my $finalFile = "${output}/homerResults.html";
      push( @result_files, "${result_dir}/${output}/homerResults.html" );
    }
    $result->{$pairName} = filter_array( \@result_files, $pattern );
  }
  return $result;
}

1;
