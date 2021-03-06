#!/usr/bin/perl
package Pipeline::Preprocession;

use strict;
use warnings;
use CQS::FileUtils;
use CQS::SystemUtils;
use CQS::ConfigUtils;
use CQS::ClassFactory;
use Pipeline::PipelineUtils;
use Data::Dumper;
use Hash::Merge qw( merge );

require Exporter;
our @ISA = qw(Exporter);

our %EXPORT_TAGS = ( 'all' => [qw(getPreprocessionConfig)] );

our @EXPORT = ( @{ $EXPORT_TAGS{'all'} } );

our $VERSION = '0.01';

sub initializeDefaultOptions {
  my $def = shift;

  initDefaultValue( $def, "perform_preprocessing",     1 );
  initDefaultValue( $def, "cluster",                   'slurm' );
  initDefaultValue( $def, "sra_to_fastq",              0 );
  initDefaultValue( $def, "merge_fastq",               0 );
  initDefaultValue( $def, "fastq_remove_N",            0 );
  initDefaultValue( $def, "perform_fastqc",            1 );
  initDefaultValue( $def, "perform_cutadapt",          0 );
  initDefaultValue( $def, "remove_sequences",          "" );
  initDefaultValue( $def, "table_vis_group_text_size", '10' );
  initDefaultValue( $def, "max_thread",                '8' );
  initDefaultValue( $def, "sequencetask_run_time",     '12' );

  return $def;
}

sub initCutadaptOption {
  my ( $config, $def, $fastq_remove_N ) = @_;

  if ( $def != $config ) {
    initDefaultValue( $config, "min_read_length", $def->{"min_read_length"} );
  }
  defined $config->{"adapter_5"} or defined $config->{"adapter_3"} or getValue( $config, "adapter" );

  my $cutadapt_option = getValue( $config, "cutadapt_option", getValue( $def, "cutadapt_option", "" ) );

  if ( $cutadapt_option !~ /\-m/ ) {
    my $min_read_length = getValue( $config, "min_read_length" );
    $cutadapt_option = $cutadapt_option . " -m " . $min_read_length;
  }
  $config->{cutadapt_option} = $cutadapt_option;
}

sub getPreprocessionConfig {
  my ($def) = @_;
  $def->{VERSION} = $VERSION;

  my $target_dir = create_directory_or_die( getValue( $def, "target_dir" ) );
  $def = initializeDefaultOptions($def);

  my $preprocessing_dir = $target_dir;
  if ($def->{perform_preprocessing} && $def->{subdir} ) {
    $preprocessing_dir = create_directory_or_die( $target_dir . "/preprocessing" );
  }

  my $is_pairend = is_pairend($def);

  #general
  my $cluster  = getValue( $def, "cluster" );
  my $task     = getValue( $def, "task_name" );
  my $email    = getValue( $def, "email" );

  #data
  my $config = {
    general => {
      task_name => $task,
      cluster   => $cluster
    },
    constraint => $def->{constraint},
    account    => $def->{account},
    files      => $def->{files},
    groups     => $def->{groups},
    pairs      => $def->{pairs},
  };
  my $source_ref = ["files"];
  my $individual = [];
  my $summary    = [];

  if ( !$def->{perform_preprocessing} ) {
    return ( $config, $individual, $summary, $source_ref, $preprocessing_dir, $source_ref );
  }

  #task
  if ( $def->{sra_to_fastq} ) {
    defined $is_pairend or die "Define is_pairend first!";
  }

  if ( $def->{merge_fastq} ) {
    defined $is_pairend or die "Define is_pairend first!";
  }

  my $fastq_remove_N   = getValue( $def, "fastq_remove_N" );
  my $remove_sequences = getValue( $def, "remove_sequences" );    #remove contamination sequences from sequence kit before adapter trimming
  my $run_cutadapt     = getValue( $def, "perform_cutadapt" );
  if ($run_cutadapt) {
    if ( defined $def->{cutadapt} ) {
      my $cconfig = $def->{cutadapt};
      initCutadaptOption( $cconfig, $def, $fastq_remove_N );
    }
    elsif ( defined $def->{cutadapt_config} ) {
      my $cconfig = $def->{cutadapt_config};
      for my $key ( keys %$cconfig ) {
        my $kconfig = $cconfig->{$key};
        initCutadaptOption( $kconfig, $def, $fastq_remove_N );
      }
    }
    else {
      initCutadaptOption( $def, $def, $fastq_remove_N );
    }
    $fastq_remove_N = 0;
  }

  if ( $def->{sra_to_fastq} ) {
    $config->{sra2fastq} = {
      class      => "SRA::FastqDump",
      perform    => 1,
      ispaired   => $is_pairend,
      target_dir => $def->{target_dir} . "/" . getNextFolderIndex($def) . "sra2fastq",
      option     => "",
      source_ref => $source_ref,
      sh_direct  => 1,
      cluster    => $def->{cluster},
      not_clean  => getValue( $def, "sra_not_clean", 1 ),
      pbs        => {
        "email"    => $def->{email},
        "nodes"    => "1:ppn=1",
        "walltime" => "10",
        "mem"      => "10gb"
      },
    };
    $source_ref = "sra2fastq";
    push @$individual, ("sra2fastq");
  }

  if ( $def->{merge_fastq} ) {
    $config->{merge_fastq} = {
      class       => "Format::MergeFastq",
      perform     => 1,
      target_dir  => $def->{target_dir} . "/" . getNextFolderIndex($def) . "merge_fastq",
      option      => "",
      source_ref  => $source_ref,
      sh_direct   => 0,
      is_paired   => $is_pairend,
      is_bzipped  => $def->{is_bzipped},
      is_collated => $def->{is_collated},
      cluster     => $def->{cluster},
      pbs         => {
        "email"    => $def->{email},
        "nodes"    => "1:ppn=1",
        "walltime" => "4",
        "mem"      => "10gb"
      }
    };
    $source_ref = "merge_fastq";
    push @$individual, ("merge_fastq");
  }

  if ($fastq_remove_N) {
    $config->{fastq_remove_N} = {
      class      => "CQS::FastqTrimmer",
      perform    => 1,
      target_dir => $def->{target_dir} . "/" . getNextFolderIndex($def) . "fastq_remove_N",
      option     => "",
      extension  => "_trim.fastq.gz",
      source_ref => $source_ref,
      sh_direct  => 1,
      cluster    => $def->{cluster},
      pbs        => {
        "email"    => $def->{email},
        "nodes"    => "1:ppn=1",
        "walltime" => "2",
        "mem"      => "10gb"
      }
    };
    $source_ref = "fastq_remove_N";
    push @$individual, ("fastq_remove_N");
  }

  if ( ( $source_ref ne "files" ) and ( defined $def->{fastqs} ) ) {
    $config->{fastqs} = $def->{fastqs};
    $source_ref = [ $source_ref, "fastq.gz\$", "fastqs" ];
  }

  if ( $def->{perform_fastqc} ) {
    addFastQC( $config, $def, $individual, $summary, "fastqc_raw", $source_ref, $preprocessing_dir );
  }

  if ( length($remove_sequences) ) {
    $config->{"remove_contamination_sequences"} = {
      class      => "CQS::Perl",
      perform    => 1,
      target_dir => $preprocessing_dir . "/" . getNextFolderIndex($def) . "remove_contamination_sequences",
      option     => $remove_sequences,
      output_ext => "_removeSeq.fastq.gz",
      perlFile   => "removeSequenceInFastq.pl",
      source_ref => $source_ref,
      sh_direct  => 1,
      cluster    => $cluster,
      pbs        => {
        "email"    => $def->{email},
        "nodes"    => "1:ppn=1",
        "walltime" => "2",
        "mem"      => "20gb"
      },
    };
    push @$individual, ("remove_contamination_sequences");
    $source_ref = [ "remove_contamination_sequences", ".fastq.gz" ];

    if ( $def->{perform_fastqc} ) {
      addFastQC( $config, $def, $individual, $summary, "fastqc_post_remove", $source_ref, $preprocessing_dir );
    }
  }

  my $untrimed_ref = $source_ref;

  if ($run_cutadapt) {
    my $cutadapt_class = ( defined $def->{cutadapt_config} ) ? "Trimmer::CutadaptByConfig" : "Trimmer::Cutadapt";
    my $cutadapt = {
      "cutadapt" => {
        class                            => $cutadapt_class,
        perform                          => 1,
        target_dir                       => $preprocessing_dir . "/" . getNextFolderIndex($def) . "cutadapt",
        option                           => $def->{cutadapt_option},
        source_ref                       => $source_ref,
        config                           => $def->{cutadapt_config},
        adapter                          => $def->{adapter},
        adapter_5                        => $def->{adapter_5},
        adapter_3                        => $def->{adapter_3},
        random_bases_remove_after_trim   => $def->{"fastq_remove_random"},
        random_bases_remove_after_trim_5 => $def->{"fastq_remove_random_5"},
        random_bases_remove_after_trim_3 => $def->{"fastq_remove_random_3"},
        fastq_remove_random              => $def->{"fastq_remove_random"},
        fastq_remove_random_5            => $def->{"fastq_remove_random_5"},
        fastq_remove_random_3            => $def->{"fastq_remove_random_3"},
        extension                        => "_clipped.fastq",
        is_paired                        => $is_pairend,
        sh_direct                        => 0,
        cluster                          => $cluster,
        pbs                              => {
          "email"    => $def->{email},
          "nodes"    => "1:ppn=1",
          "walltime" => "24",
          "mem"      => "20gb"
        },
      }
    };
    if ( defined $def->{cutadapt} ) {
      $cutadapt->{cutadapt} = merge( $def->{cutadapt}, $cutadapt->{cutadapt} );
    }

    $config = merge( $config, $cutadapt );
    push @$individual, ("cutadapt");

    if ( $def->{perform_fastqc} ) {
      addFastQC( $config, $def, $individual, $summary, "fastqc_post_trim", [ "cutadapt", ".fastq.gz" ], $preprocessing_dir );
    }
    $source_ref = [ "cutadapt", ".fastq.gz" ];
  }

  if ( $run_cutadapt or $def->{fastq_len} ) {
    my $fastq_len_dir = $preprocessing_dir . "/" . getNextFolderIndex($def) . "fastq_len";
    my $fastq_len     = {
      "fastq_len" => {
        class      => "CQS::FastqLen",
        perform    => 1,
        target_dir => $fastq_len_dir,
        option     => "",
        source_ref => $run_cutadapt ? "cutadapt" : $source_ref,
        cqstools   => $def->{cqstools},
        sh_direct  => 1,
        cluster    => $cluster,
        pbs        => {
          "email"    => $def->{email},
          "nodes"    => "1:ppn=1",
          "walltime" => "24",
          "mem"      => "20gb"
        },
      },
      "fastq_len_vis" => {
        class                    => "CQS::UniqueR",
        perform                  => 1,
        target_dir               => $fastq_len_dir,
        rtemplate                => "countTableVisFunctions.R,fastqLengthVis.R",
        output_file              => ".lengthDistribution",
        output_file_ext          => ".png",
        parameterSampleFile1_ref => [ "fastq_len", ".len\$" ],
        parameterSampleFile2     => $def->{groups},
        sh_direct                => 1,
        pbs                      => {
          "email"    => $def->{email},
          "nodes"    => "1:ppn=1",
          "walltime" => "1",
          "mem"      => "10gb"
        },
      }
    };

    $config = merge( $config, $fastq_len );

    push @$individual, ("fastq_len");
    push @$summary,    ("fastq_len_vis");
  }

  if ( $def->{perform_fastqc} ) {
    my $fastqc_count_vis_files = undef;
    if ( length($remove_sequences) && $run_cutadapt ) {
      $fastqc_count_vis_files = {
        target_dir         => $config->{fastqc_post_trim}->{target_dir},
        parameterFile2_ref => [ "fastqc_post_remove_summary", ".FastQC.summary.reads.tsv\$" ],
        parameterFile3_ref => [ "fastqc_post_trim_summary", ".FastQC.summary.reads.tsv\$" ],
      };
    }
    elsif ( length($remove_sequences) ) {
      $fastqc_count_vis_files = {
        target_dir         => $config->{fastqc_post_remove}->{target_dir},
        parameterFile2_ref => [ "fastqc_post_remove_summary", ".FastQC.summary.reads.tsv\$" ],
      };
    }
    elsif ($run_cutadapt) {
      $fastqc_count_vis_files = {
        target_dir         => $config->{fastqc_post_trim}->{target_dir},
        parameterFile2_ref => [ "fastqc_post_trim_summary", ".FastQC.summary.reads.tsv\$" ],
      };
    }
    else {
      $fastqc_count_vis_files = { target_dir => $config->{fastqc_raw}->{target_dir}, };
    }

    if ( defined $fastqc_count_vis_files ) {
      $config->{"fastqc_count_vis"} = merge(
        {
          class              => "CQS::UniqueR",
          perform            => 1,
          rtemplate          => "countInFastQcVis.R",
          output_file        => ".countInFastQcVis.Result",
          output_file_ext    => ".Reads.csv;.pdf",
          sh_direct          => 1,
          parameterFile1_ref => [ "fastqc_raw_summary", ".FastQC.summary.reads.tsv\$" ],
          pbs                => {
            "email"    => $def->{email},
            "nodes"    => "1:ppn=1",
            "walltime" => "1",
            "mem"      => "10gb"
          },
        },
        $fastqc_count_vis_files
      );
      push @$summary, ("fastqc_count_vis");
    }
  }

  return ( $config, $individual, $summary, $source_ref, $preprocessing_dir, $untrimed_ref );
}

1;
