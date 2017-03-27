#!/usr/bin/perl
package Comparison::DESeq2;

use strict;
use warnings;
use Data::Dumper;
use File::Basename;
use CQS::PBS;
use CQS::ConfigUtils;
use CQS::SystemUtils;
use CQS::FileUtils;
use CQS::NGSCommon;
use CQS::UniqueTask;
use CQS::StringUtils;

our @ISA = qw(CQS::UniqueTask);

my $directory;

sub new {
  my ($class) = @_;
  my $self = $class->SUPER::new();
  $self->{_name}   = __PACKAGE__;
  $self->{_suffix} = "_de2";
  bless $self, $class;
  return $self;
}

sub getSuffix {
  my ( $top25only, $detectedInBothGroup, $minMedianInGroup ) = @_;
  my $suffix = "";
  if ($top25only) {
    $suffix = $suffix . "_top25";
  }
  if ($detectedInBothGroup) {
    $suffix = $suffix . "_detectedInBothGroup";
  }
  if ( $minMedianInGroup > 0 ) {
    $suffix = $suffix . "_min${minMedianInGroup}";
  }
  return $suffix;
}

sub perform {
  my ( $self, $config, $section ) = @_;

  my ( $task_name, $path_file, $pbs_desc, $target_dir, $log_dir, $pbs_dir, $result_dir, $option, $sh_direct, $cluster ) = get_parameter( $config, $section );

  my $comparisons = get_raw_files( $config, $section );
  my @comparison_names = keys %{$comparisons};

  my $comparisonAttributes = get_raw_files_attributes( $config, $section );
  my $comparisonTitles = \@comparison_names;
  if ( defined $comparisonAttributes->{".order"} && defined $comparisonAttributes->{".col"} ) {
    $comparisonTitles = $comparisonAttributes->{".col"};
  }

  my $totalPair = scalar(@comparison_names);
  if ( 0 == $totalPair ) {
    die "No pair defined!";
  }

  my $groups = get_raw_files( $config, $section, "groups" );

  my $countfile = parse_param_file( $config, $section, "countfile", 1 );
  my $rtemplate = dirname(__FILE__) . "/DESeq2.r";
  if ( !-e $rtemplate ) {
    die "File not found : " . $rtemplate;
  }

  my $showLabelInPCA    = get_option( $config, $section, "show_label_PCA",       1 );
  my $showDEGeneCluster = get_option( $config, $section, "show_DE_gene_cluster", 0 );
  my $pvalue            = get_option( $config, $section, "pvalue",               0.05 );
  my $foldChange        = get_option( $config, $section, "fold_change",          2.0 );
  my $minMedianInGroup  = get_option( $config, $section, "min_median_read",      0 );
  my $addCountOne       = get_option( $config, $section, "add_count_one",        0 );
  my $usePearsonInHCA   = get_option( $config, $section, "use_pearson_in_hca",   0 );

  my $top25only           = get_option( $config, $section, "top25only",              0 );
  my $detectedInBothGroup = get_option( $config, $section, "detected_in_both_group", 0 );
  my $performWilcox       = get_option( $config, $section, "perform_wilcox",         0 );
  my $useRawPvalue        = get_option( $config, $section, "use_raw_p_value",        0 );
  my $textSize            = get_option( $config, $section, "text_size",              11 );

  my $libraryFile = parse_param_file( $config, $section, "library_file", 0 );
  my $libraryKey;
  if ( defined $libraryFile ) {
    $libraryKey = get_option( $config, $section, "library_key", "TotalReads" );
  }

  my $suffix = getSuffix( $top25only, $detectedInBothGroup, $minMedianInGroup );

  my %tpgroups = ();
  for my $group_name ( sort keys %{$groups} ) {
    my @samples = @{ $groups->{$group_name} };
    $tpgroups{$group_name} = "\"" . join( "\",\"", @samples ) . "\"";
  }

  my $first = 0;

  my $countfiles = get_raw_files( $config, $section, "countfile" );
  my $single_count_file = 1;
  if ( ref $countfiles eq ref {} ) {
    if ( scalar( keys %$countfiles ) > 1 ) {
      $single_count_file = 0;
    }
  }

  my $designfilename = "${task_name}.define";
  my $designfile     = "$result_dir/$designfilename";
  open( my $df, ">$designfile" ) or die "Cannot create $designfile";
  print $df "ComparisonName\tCountFile\tConditionFile\tReferenceGroupName\tSampleGroupName\tComparisonTitle\n";

  for my $comparisonIndex ( 0 .. $#comparison_names ) {
    my $comparison_name = $comparison_names[$comparisonIndex];
    my $comparisonTitle = $comparisonTitles->[$comparisonIndex];
    $first++;

    my $covariances = {};

    my $gNames = $comparisons->{$comparison_name};
    my @group_names;

    if ( ref $gNames eq ref {} ) {
      @group_names = @{ $gNames->{groups} };
      for my $key ( sort keys %$gNames ) {
        next if ( $key eq "groups" );
        $covariances->{$key} = $gNames->{$key};
      }
    }
    else {
      @group_names = @{$gNames};
    }
    my @covariances_keys = sort keys %$covariances;

    #print( Dumper(@group_names) );

    if ( scalar(@group_names) != 2 ) {
      die "Comparison of $comparison_name should contains and only contains two groups!";
    }

    my $g1 = $group_names[0];
    my $g2 = $group_names[1];
    my @s1 = @{ $groups->{$g1} };
    my @s2 = @{ $groups->{$g2} };

    my $total_sample_count = scalar(@s1) + scalar(@s2);

    for my $key ( keys %$covariances ) {
      my $values = $covariances->{$key};
      if ( !( ref $values eq ref [] ) ) {
        die "Covariances of " . $key . " should be array reference!";
      }

      if ( scalar(@$values) != $total_sample_count ) {
        die "Number of covariance value of " . $key . " shoud be $total_sample_count !";
      }
    }

    my $filename = "${comparison_name}.design";

    my $cdfile = $result_dir . "/$filename";
    open( my $cd, ">$cdfile" ) or die "Cannot create $cdfile";
    if ( scalar(@covariances_keys) > 0 ) {
      print $cd "Sample\tCondition\t", join( "\t", @covariances_keys ), "\n";
    }
    else {
      print $cd "Sample\tCondition\n";
    }
    for my $i ( 0 .. $#s1 ) {
      my $sname = $s1[$i];
      print $cd "${sname}\t${g1}";
      if ( scalar(@covariances_keys) > 0 ) {
        for my $key (@covariances_keys) {
          print $cd "\t" . $covariances->{$key}[$i];
        }
      }
      print $cd "\n";
    }
    for my $i ( 0 .. $#s2 ) {
      my $sname = $s2[$i];
      print $cd "${sname}\t${g2}";
      if ( scalar(@covariances_keys) > 0 ) {
        for my $key (@covariances_keys) {
          print $cd "\t" . $covariances->{$key}[ $i + scalar(@s1) ];
        }
      }
      print $cd "\n";
    }
    close $cd;

    my $curcountfile = $single_count_file ? $countfile : $countfiles->{$comparison_name};
    if ( !defined $curcountfile ) {
      print Dumper($countfiles);
      die "Count file not found for comparison of $comparison_name!";
    }
    if ( ref $curcountfile eq ref [] ) {
      $curcountfile = $curcountfile->[0];
    }
    print $df "$comparison_name\t$curcountfile\t$cdfile\t$g1\t$g2\t$comparisonTitle\n";
  }
  close($df);

  my $rfile = $result_dir . "/${task_name}.r";
  open( my $rf, ">$rfile" )     or die "Cannot create $rfile";
  open( my $rt, "<$rtemplate" ) or die $!;
  print $rf "
rootdir<-\"$result_dir\"
inputfile<-\"$designfilename\" 
  
showLabelInPCA<-$showLabelInPCA
showDEGeneCluster<-$showDEGeneCluster
pvalue<-$pvalue
foldChange<-$foldChange
minMedianInGroup<-$minMedianInGroup
addCountOne<-$addCountOne
usePearsonInHCA<-$usePearsonInHCA
top25only<-$top25only
detectedInBothGroup<-$detectedInBothGroup
performWilcox<-$performWilcox
useRawPvalue<-$useRawPvalue
textSize<-$textSize
";

if(defined $libraryFile){
  print $rf "
libraryFile<-\"$libraryFile\"
libraryKey<-\"$libraryKey\"
";
}

  while (<$rt>) {
    if ( $_ !~ 'predefined_condition_end' ) {
      next;
    }
    last;
  }
  while (<$rt>) {
    s/\r|\n//g;
    print $rf $_, "\n";
  }
  close $rt;
  close $rf;

  my $pbs_file = $self->get_pbs_filename( $pbs_dir, $task_name );
  my $pbs_name = basename($pbs_file);
  my $log      = $self->get_log_filename( $log_dir, $task_name );
  my $log_desc = $cluster->get_log_description($log);

  my $lastComparisonName = $comparison_names[-1];
  my $final_file         = $lastComparisonName . $suffix . "_DESeq2_sig.csv";
  my $pbs                = $self->open_pbs( $pbs_file, $pbs_desc, $log_desc, $path_file, $result_dir, $final_file );

  print $pbs "R --vanilla -f $rfile \n";

  $self->close_pbs( $pbs, $pbs_file );
}

sub result {
  my ( $self, $config, $section, $pattern ) = @_;

  my ( $task_name, $path_file, $pbs_desc, $target_dir, $log_dir, $pbs_dir, $result_dir, $option, $sh_direct ) = get_parameter( $config, $section, 0 );

  my $comparisons = get_raw_files( $config, $section );
  my $minMedianInGroup    = get_option( $config, $section, "min_median_read",        0 );
  my $top25only           = get_option( $config, $section, "top25only",              0 );
  my $detectedInBothGroup = get_option( $config, $section, "detected_in_both_group", 0 );
  my $performWilcox       = get_option( $config, $section, "perform_wilcox",         0 );

  my $suffix = getSuffix( $top25only, $detectedInBothGroup, $minMedianInGroup );
  my $result = {};
  for my $comparison_name ( sort keys %{$comparisons} ) {
    my @result_files = ();
    my $prefix       = $comparison_name . $suffix;

    my $final_file = $prefix . "_DESeq2_sig.csv";

    push( @result_files, $result_dir . "/${prefix}.csv" );
    push( @result_files, $result_dir . "/${prefix}_DESeq2.csv" );
    push( @result_files, $result_dir . "/${prefix}_DESeq2_sig.csv" );
    if ($performWilcox) {
      push( @result_files, $result_dir . "/${prefix}_quantile_wilcox.csv" );
      push( @result_files, $result_dir . "/${prefix}_quantile_wilcox_sig.csv" );
    }

    $result->{$comparison_name} = filter_array( \@result_files, $pattern );
  }

  return $result;
}

1;
