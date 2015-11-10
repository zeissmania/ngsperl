#!/usr/bin/perl
package Variants::GlmvcValidate;

use strict;
use warnings;
use File::Basename;
use CQS::PBS;
use CQS::ConfigUtils;
use CQS::SystemUtils;
use CQS::FileUtils;
use CQS::GroupTask;
use CQS::NGSCommon;
use CQS::StringUtils;

our @ISA = qw(CQS::GroupTask);

sub new {
  my ($class) = @_;
  my $self = $class->SUPER::new();
  $self->{_name}   = "GlmvcValidate";
  $self->{_suffix} = "_gv";
  bless $self, $class;
  return $self;
}

sub perform {
  my ( $self, $config, $section ) = @_;

  my ( $task_name, $path_file, $pbsDesc, $target_dir, $logDir, $pbsDir, $resultDir, $option, $sh_direct, $cluster, $thread ) = get_parameter( $config, $section );

  my $glmvcfile = get_param_file( $config->{$section}{execute_file}, "execute_file", 1 );
  my $source_type = $config->{$section}{source_type} or die "source_type is not defined in $section";

  my $rawFiles = get_raw_files( $config, $section );

  my $validateFiles = get_raw_files( $config, $section, "validation_files" );

  my %group_sample_map = ();

  my $fafile           = "";
  my $mpileupParameter = "";
  my $isbam            = lc($source_type) eq "bam";
  if ($isbam) {
    $fafile = get_param_file( $config->{$section}{fasta_file}, "fasta_file (for mpileup)", 1 );
    $mpileupParameter = $config->{$section}{mpileup_option};
    if ( defined $mpileupParameter ) {
      if ( $mpileupParameter eq "" ) {
        undef($$mpileupParameter);
      }
    }

    my $groups = get_raw_files( $config, $section, "groups" );
    for my $groupName ( sort keys %{$groups} ) {
      my @samples = @{ $groups->{$groupName} };
      my @gfiles  = ();
      my $index   = 0;
      foreach my $sampleName (@samples) {
        my @sampleBamFiles = @{ $rawFiles->{$sampleName} };
        push( @gfiles, $sampleBamFiles[0] );
      }
      $group_sample_map{$groupName} = \@gfiles;
    }
  }
  else {
    %group_sample_map = %{$rawFiles};
  }

  my $shfile = $self->taskfile( $pbsDir, $task_name );
  open( SH, ">$shfile" ) or die "Cannot create $shfile";
  print SH get_run_command($sh_direct) . "\n";

  for my $groupName ( sort keys %group_sample_map ) {
    my $validateFile;
    if ( ref($validateFiles) eq 'HASH' ) {
      if ( defined $validateFiles->{$groupName} ) {
        $validateFile = $validateFiles->{$groupName}[0];
      }
      else {
        $validateFile = $validateFiles->{$task_name}[0];
      }
    }
    elsif ( ref($validateFiles) eq 'ARRAY' ) {
      $validateFile = $validateFiles->[0];
    }
    else {
      $validateFile = $validateFiles;
    }

    my @sampleFiles = @{ $group_sample_map{$groupName} };
    my $sampleCount = scalar(@sampleFiles);

    my $curDir = create_directory_or_die( $resultDir . "/$groupName" );

    my $pbsFile = $self->pbsfile( $pbsDir, $groupName );
    my $pbsName = basename($pbsFile);
    my $log     = $self->logfile( $logDir, $groupName );

    print SH "\$MYCMD ./$pbsName \n";

    my $log_desc = $cluster->get_log_desc($log);

    open( OUT, ">$pbsFile" ) or die $!;
    print OUT "$pbsDesc
$log_desc

$path_file 

echo Glmvc=`date` 

cd $curDir
";

    my $final = "${groupName}.validation.tsv";
    if ($isbam) {
      if ( $sampleCount != 2 ) {
        die "SampleFile should be normal,tumor paired for " . $groupName . ".";
      }
      my $normal = $sampleFiles[0];
      my $tumor  = $sampleFiles[1];

      my $cmd;
      if ( defined $mpileupParameter ) {
        $cmd = "samtools mpileup -f $fafile $mpileupParameter $normal $tumor | mono-sgen $glmvcfile validate -t console $option -o ${curDir}/${groupName}.validation -v $validateFile";
      }
      else {
        $cmd = "mono $glmvcfile validate -c $thread -t bam -f $fafile $option --normal $normal --tumor $tumor -o ${curDir}/${groupName}.validation -v $validateFile";
      }

      print OUT "
if [ -s $final ]; then
  echo job has already been done. if you want to do again, delete ${curDir}/${final} and submit job again.
  exit 0;
fi      
      
if [ ! -s ${normal}.bai ]; then
  samtools index ${normal}
fi

if [ ! -s ${tumor}.bai ]; then
  samtools index ${tumor}
fi

$cmd

";
    }
    else {
      print OUT "mono-sgen $glmvcfile validate -t mpileup -m $sampleFiles[0] $option -o ${curDir}/${groupName}.validation -v $validateFile \n";
    }

    print OUT "echo finished=`date` \n";

    close OUT;

    print "$pbsFile created \n";

  }
  close(SH);

  if ( is_linux() ) {
    chmod 0755, $shfile;
  }

  print "!!!shell file $shfile created, you can run this shell file to submit all " . $self->{_name} . " tasks.\n";
}

sub result {
  my ( $self, $config, $section, $pattern ) = @_;

  my ( $task_name, $path_file, $pbsDesc, $target_dir, $logDir, $pbsDir, $resultDir, $option, $sh_direct ) = get_parameter( $config, $section );

  my %group_sample_map = ();
  my $source_type      = $config->{$section}{source_type} or die "source_type is not defined in $section";
  my $isbam            = lc($source_type) eq "bam";
  if ($isbam) {
    %group_sample_map = %{ get_raw_files( $config, $section, "groups" ) };
  }
  else {
    %group_sample_map = %{ get_raw_files( $config, $section ) };
  }

  my $result = {};
  for my $groupName ( keys %group_sample_map ) {
    my @resultFiles = ();
    my $curDir      = $resultDir . "/$groupName";

    my $final = "$curDir/${groupName}.validation.tsv";

    push( @resultFiles, "$final" );
    $result->{$groupName} = filter_array( \@resultFiles, $pattern );
  }
  return $result;
}

1;
