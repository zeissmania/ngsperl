#!/usr/bin/perl
package Pipeline::SmallRNAUtils;

use strict;
use warnings;
use CQS::FileUtils;
use CQS::SystemUtils;
use CQS::ConfigUtils;
use CQS::ClassFactory;
use Data::Dumper;
use Hash::Merge qw( merge );

require Exporter;
our @ISA = qw(Exporter);

our %EXPORT_TAGS = ( 'all' => [qw(getSmallRNADefinition getPrepareConfig)] );

our @EXPORT = ( @{ $EXPORT_TAGS{'all'} } );

our $VERSION = '0.01';

#an example of parameter userdef
#my $userdef = {
#
#  #General options
#  task_name  => "parclip_NIH",
#  email      => "quanhu.sheng\@vanderbilt.edu",
#  target_dir => "/scratch/cqs/shengq1/vickers/20150925_parclip_3018-KCV-15/",
#  max_thread => 8,
#  cluster    => "slurm",
#  search_not_identical => 0,
#
#  #Default software parameter (don't change it except you really know it)
#  fastq_remove_N => 0,
#  adapter        => "TGGAATTCTCGGGTGCCAAGG",
#
#  cqstools   => "/home/shengq1/cqstools/CQS.Tools.exe",
#
#  #Data
#  files => {
#    "3018-KCV-15-15" => ["/gpfs21/scratch/cqs/shengq1/vickers/data/3018-KCV-15_parclip/3018-KCV-15-15_ATGTCA_L006_R1_001.fastq.gz"],
#    "3018-KCV-15-36" => ["/gpfs21/scratch/cqs/shengq1/vickers/data/3018-KCV-15_parclip/3018-KCV-15-36_CCAACA_L006_R1_001.fastq.gz"],
#    "3018-KCV-15-37" => ["/gpfs21/scratch/cqs/shengq1/vickers/data/3018-KCV-15_parclip/3018-KCV-15-37_CGGAAT_L006_R1_001.fastq.gz"],
#    "3018-KCV-15-46" => ["/gpfs21/scratch/cqs/shengq1/vickers/data/3018-KCV-15_parclip/3018-KCV-15-46_TCCCGA_L006_R1_001.fastq.gz"],
#    "3018-KCV-15-47" => ["/gpfs21/scratch/cqs/shengq1/vickers/data/3018-KCV-15_parclip/3018-KCV-15-47_TCGAAG_L006_R1_001.fastq.gz"],
#  },
#};
#
#an example of paramter $genome
#my $genome = {
#  #genome database
#  mirbase_count_option  => "-p hsa",
#  coordinate            => "/scratch/cqs/shengq1/references/smallrna/hg19_miRBase20_ucsc-tRNA_ensembl75.bed",
#  coordinate_fasta      => "/scratch/cqs/shengq1/references/smallrna/hg19_miRBase20_ucsc-tRNA_ensembl75.bed.fa",
#  bowtie1_index         => "/scratch/cqs/shengq1/references/hg19_16569_MT/bowtie_index_1.1.2/hg19_16569_MT",
#  bowtie1_miRBase_index => "/data/cqs/shengq1/reference/miRBase20/bowtie_index_1.1.1/mature.dna",
#  gsnap_index_directory => "/scratch/cqs/shengq1/references/hg19_16569_MT/gsnap_index_k14_2015-06-23/",
#  gsnap_index_name      => "hg19_16569_MT",
#  star_index_directory => "/scratch/cqs/shengq1/references/hg19_16569_MT/STAR_index_v37.75_2.4.2a_sjdb49"
#};

sub initializeDefaultOptions {
  my $def = shift;

  if ( !defined $def->{cluster} ) {
    $def->{cluster} = 'slurm';
  }

  if ( !defined $def->{min_read_length} ) {
    $def->{min_read_length} = 16;
  }

  if ( !defined $def->{micrornacount_offsets} ) {
    $def->{micrornacount_offsets} = '0,1,2';
  }

  if ( !defined $def->{smallrnacount_option} ) {
    $def->{smallrnacount_option} = '';
  }

  if ( !defined $def->{bowtie1_option_1mm} ) {
    $def->{bowtie1_option_1mm} = '-a -m 100 --best --strata -v 1';
  }

  if ( !defined $def->{bowtie1_option_pm} ) {
    $def->{bowtie1_option_pm} = '-a -m 1000 --best --strata -v 0';
  }

  if ( !defined $def->{fastq_remove_N} ) {
    $def->{fastq_remove_N} = 1;
  }

  if ( !defined $def->{run_cutadapt} ) {
    $def->{run_cutadapt} = 1;
  }

  if ( !defined $def->{fastq_remove_random} ) {
    $def->{fastq_remove_random} = 0;
  }

  if ( !defined $def->{remove_sequences} ) {
    $def->{remove_sequences} = "";
  }

  if ( !defined $def->{has_NTA} ) {
    $def->{has_NTA} = 1;
  }

  if ( !defined $def->{mirbase_count_option} ) {
    $def->{mirbase_count_option} = "";
  }

  if ( !defined $def->{table_vis_group_text_size} ) {
    $def->{table_vis_group_text_size} = "10";
  }

  if ( !defined $def->{sequencetask_run_time} ) {
    $def->{sequencetask_run_time} = "12";
  }

  if ( !defined $def->{DE_show_gene_cluster} ) {
    $def->{DE_show_gene_cluster} = 1;
  }

  if ( !defined $def->{DE_pvalue} ) {
    $def->{DE_pvalue} = 0.05;
  }

  if ( !defined $def->{DE_fold_change} ) {
    $def->{DE_fold_change} = 1.5;
  }

  if ( !defined $def->{DE_add_count_one} ) {
    $def->{DE_add_count_one} = 0;
  }

  if ( !defined $def->{DE_min_median_read_top} ) {
    $def->{DE_min_median_read_top} = 2;
  }

  if ( !defined $def->{DE_min_median_read_smallRNA} ) {
    $def->{DE_min_median_read_smallRNA} = 5;
  }

  if ( !defined $def->{DE_top25only} ) {
    $def->{DE_top25only} = 0;
  }

  if ( !defined $def->{DE_detected_in_both_group} ) {
    $def->{DE_detected_in_both_group} = 1;
  }

  if ( !defined $def->{DE_perform_wilcox} ) {
    $def->{DE_perform_wilcox} = 0;
  }

  if ( !defined $def->{DE_use_raw_pvalue} ) {
    $def->{DE_use_raw_pvalue} = 1;
  }

  if ( !defined $def->{max_sequence_extension_base} ) {
    $def->{max_sequence_extension_base} = 1;
  }

  if ( !defined $def->{top_read_number} ) {
    $def->{top_read_number} = 100;
  }

  if ( !defined $def->{blast_top_reads} ) {
    $def->{blast_top_reads} = 0;
  }

  if ( !defined $def->{blast_localdb} ) {
    $def->{blast_localdb} = "";
  }

  if ( !defined $def->{perform_contig_analysis} ) {
    $def->{perform_contig_analysis} = 0;
  }

  if ( !defined $def->{consider_tRNA_NTA} ) {
    $def->{consider_tRNA_NTA} = 0;
  }

  if ( !defined $def->{perform_tDRmapper} ) {
    $def->{perform_tDRmapper} = 0;
  }
  return $def;
}

sub getSmallRNADefinition {
  my ( $userdef, $genome ) = @_;

  my $def = merge( $userdef, $genome );

  $def = initializeDefaultOptions($def);

  return $def;
}

sub getPrepareConfig {
  my ($def) = @_;

  #print Dumper($def);

  create_directory_or_die( $def->{target_dir} );

  my $preprocessing_dir     = create_directory_or_die( $def->{target_dir} . "/preprocessing" );
  my $class_independent_dir = create_directory_or_die( $def->{target_dir} . "/class_independent" );

  $def = initializeDefaultOptions($def);

  my $cluster                        = $def->{cluster};
  my $fastq_remove_N                 = $def->{fastq_remove_N};
  my $run_cutadapt                   = $def->{run_cutadapt};
  my $fastq_remove_random            = $def->{fastq_remove_random};
  my $remove_contamination_sequences = $def->{remove_sequences} ne "";
  my $hasNTA                         = $def->{has_NTA};
  my $groups                         = $def->{groups};
  my $pairs                          = $def->{pairs};

  my $max_sequence_extension_base = $def->{max_sequence_extension_base};
  my $blast_top_reads             = $def->{blast_top_reads};
  my $blast_localdb               = $def->{blast_localdb};

  my $perform_tDRmapper = defined $def->{perform_tDRmapper} && $def->{perform_tDRmapper} && defined $def->{tDRmapper} && defined $def->{tDRmapper_fasta};

  my $top_read_number = $def->{top_read_number};

  my $config = {
    general => {
      task_name => $def->{task_name},
      cluster   => $cluster
    },
    files => $def->{files}
  };

  if ( defined $def->{groups} ) {
    $config->{groups} = $def->{groups};
  }

  if ( defined $def->{pairs} ) {
    $config->{pairs} = $def->{pairs};
  }

  my @individual = ();
  my @summary    = ();

  my $source_ref = "files";
  my $len_ref    = "files";
  if ( $fastq_remove_N && !$run_cutadapt ) {
    $config->{fastq_remove_N} = {
      class      => "CQS::FastqTrimmer",
      perform    => $fastq_remove_N,
      target_dir => $preprocessing_dir . "/fastq_remove_N",
      option     => "-n -z",
      extension  => "_trim.fastq.gz",
      source_ref => "files",
      cqstools   => $def->{cqstools},
      cluster    => $cluster,
      sh_direct  => 1,
      pbs        => {
        "email"    => $def->{email},
        "nodes"    => "1:ppn=1",
        "walltime" => "2",
        "mem"      => "10gb"
      }
    };
    $source_ref = "fastq_remove_N";
    $len_ref    = "fastq_remove_N";
    push @individual, "fastq_remove_N";
  }

  $config->{"fastqc_raw"} = {
    class      => "QC::FastQC",
    perform    => 1,
    target_dir => $preprocessing_dir . "/fastqc_raw",
    option     => "",
    source_ref => $source_ref,
    cluster    => $cluster,
    pbs        => {
      "email"    => $def->{email},
      "nodes"    => "1:ppn=1",
      "walltime" => "2",
      "mem"      => "10gb"
    },
  };
  $config->{"fastqc_raw_summary"} = {
    class      => "QC::FastQCSummary",
    perform    => 1,
    target_dir => $preprocessing_dir . "/fastqc_raw",
    cqstools   => $def->{cqstools},
    option     => "",
    cluster    => $cluster,
    pbs        => {
      "email"    => $def->{email},
      "nodes"    => "1:ppn=1",
      "walltime" => "2",
      "mem"      => "10gb"
    },
  };
  push @individual, ("fastqc_raw");
  push @summary,    ("fastqc_raw_summary");

  if ($remove_contamination_sequences) {
    $config->{"remove_contamination_sequences"} = {
      class      => "CQS::Perl",
      perform    => 1,
      target_dir => $preprocessing_dir . "/remove_contamination_sequences",
      option     => $def->{remove_sequences},
      output_ext => "_removeSeq.fastq.gz",
      perlFile   => "removeSequenceInFastq.pl",
      source_ref => $source_ref,
      sh_direct  => 0,
      cluster    => $cluster,
      pbs        => {
        "email"    => $def->{email},
        "nodes"    => "1:ppn=1",
        "walltime" => "2",
        "mem"      => "20gb"
      },
    };
    push @individual, ("remove_contamination_sequences");
    $source_ref = [ "remove_contamination_sequences", ".fastq.gz" ];
    $len_ref = "remove_contamination_sequences";

    $config->{"fastqc_post_remove"} = {
      class      => "QC::FastQC",
      perform    => 1,
      target_dir => $preprocessing_dir . "/fastqc_post_remove",
      option     => "",
      source_ref => $source_ref,
      cluster    => $cluster,
      pbs        => {
        "email"    => $def->{email},
        "nodes"    => "1:ppn=1",
        "walltime" => "2",
        "mem"      => "10gb"
      },
    };
    $config->{"fastqc_post_remove_summary"} = {
      class      => "QC::FastQCSummary",
      perform    => 1,
      target_dir => $preprocessing_dir . "/fastqc_post_remove",
      cqstools   => $def->{cqstools},
      option     => "",
      cluster    => $cluster,
      pbs        => {
        "email"    => $def->{email},
        "nodes"    => "1:ppn=1",
        "walltime" => "2",
        "mem"      => "10gb"
      },
    };
    push @individual, ("fastqc_post_remove");
    push @summary,    ("fastqc_post_remove_summary");

    if ( !$run_cutadapt ) {    #remove sequence but not trimming adapter
      $config->{"fastqc_count_vis"} = {
        class              => "CQS::UniqueR",
        perform            => 1,
        target_dir         => $preprocessing_dir . "/fastqc_post_remove",
        rtemplate          => "countInFastQcVis.R",
        output_file        => ".countInFastQcVis.Result",
        output_file_ext    => ".Reads.csv",
        parameterFile1_ref => [ "fastqc_raw_summary", ".FastQC.summary.reads.tsv\$" ],
        parameterFile2_ref => [ "fastqc_post_remove_summary", ".FastQC.summary.reads.tsv\$" ],
        sh_direct          => 1,
        pbs                => {
          "email"    => $def->{email},
          "nodes"    => "1:ppn=1",
          "walltime" => "1",
          "mem"      => "10gb"
        },
      };
      push @summary, ("fastqc_count_vis");
    }
  }

  if ($run_cutadapt) {
    my $adapter = $def->{adapter};
    if ( !defined $adapter ) {
      $adapter = "TGGAATTCTCGGGTGCCAAGG";
    }

    my $cutadapt_option = $def->{cutadapt_option};
    if ( !defined $cutadapt_option ) {
      $cutadapt_option = "-m " . $def->{min_read_length};
    }

    my $cutadaptModules = {
      cutadapt => {
        class                          => "Trimmer::Cutadapt",
        perform                        => 1,
        target_dir                     => $preprocessing_dir . "/cutadapt",
        option                         => $cutadapt_option,
        source_ref                     => $source_ref,
        adapter                        => $adapter,
        extension                      => "_clipped.fastq",
        random_bases_remove_after_trim => $fastq_remove_random,
        sh_direct                      => 0,
        cluster                        => $cluster,
        pbs                            => {
          "email"    => $def->{email},
          "nodes"    => "1:ppn=1",
          "walltime" => "24",
          "mem"      => "20gb"
        },
      },
      fastqc_post_trim => {
        class      => "QC::FastQC",
        perform    => 1,
        target_dir => $preprocessing_dir . "/fastqc_post_trim",
        option     => "",
        sh_direct  => 1,
        source_ref => [ "cutadapt", ".fastq.gz" ],
        cluster    => $cluster,
        pbs        => {
          "email"    => $def->{email},
          "nodes"    => "1:ppn=1",
          "walltime" => "2",
          "mem"      => "10gb"
        },
      },
      fastqc_post_trim_summary => {
        class      => "QC::FastQCSummary",
        perform    => 1,
        sh_direct  => 1,
        target_dir => $preprocessing_dir . "/fastqc_post_trim",
        cqstools   => $def->{cqstools},
        option     => "",
        cluster    => $cluster,
        pbs        => {
          "email"    => $def->{email},
          "nodes"    => "1:ppn=1",
          "walltime" => "2",
          "mem"      => "10gb"
        },
      }
    };
    $config = merge( $config, $cutadaptModules );

    $source_ref = [ "cutadapt", ".fastq.gz" ];
    $len_ref = "cutadapt";
    push @individual, ( "cutadapt", "fastqc_post_trim" );
    push @summary, ("fastqc_post_trim_summary");

    if ( !$remove_contamination_sequences ) {    #trimming adapter but not remove sequence
      $config->{"fastqc_count_vis"} = {
        class              => "CQS::UniqueR",
        perform            => 1,
        target_dir         => $preprocessing_dir . "/fastqc_post_trim",
        rtemplate          => "countInFastQcVis.R",
        output_file        => ".countInFastQcVis.Result",
        output_file_ext    => ".Reads.csv",
        parameterFile1_ref => [ "fastqc_raw_summary", ".FastQC.summary.reads.tsv\$" ],
        parameterFile2_ref => [ "fastqc_post_trim_summary", ".FastQC.summary.reads.tsv\$" ],
        sh_direct          => 1,
        pbs                => {
          "email"    => $def->{email},
          "nodes"    => "1:ppn=1",
          "walltime" => "1",
          "mem"      => "10gb"
        },
      };
      push @summary, ("fastqc_count_vis");
    }
  }

  if ( $remove_contamination_sequences and $run_cutadapt ) {
    $config->{"fastqc_count_vis"} = {
      class              => "CQS::UniqueR",
      perform            => 1,
      target_dir         => $preprocessing_dir . "/fastqc_post_trim",
      rtemplate          => "countInFastQcVis.R",
      output_file        => ".countInFastQcVis.Result",
      output_file_ext    => ".Reads.csv",
      parameterFile1_ref => [ "fastqc_raw_summary", ".FastQC.summary.reads.tsv\$" ],
      parameterFile2_ref => [ "fastqc_post_remove_summary", ".FastQC.summary.reads.tsv\$" ],
      parameterFile3_ref => [ "fastqc_post_trim_summary", ".FastQC.summary.reads.tsv\$" ],
      sh_direct          => 1,
      pbs                => {
        "email"    => $def->{email},
        "nodes"    => "1:ppn=1",
        "walltime" => "1",
        "mem"      => "10gb"
      },
    };
    push @summary, ("fastqc_count_vis");
  }

  #tDRmapper
  if ($perform_tDRmapper) {
    $config->{"tDRmapper"} = {
      class      => "CQS::Perl",
      perform    => 1,
      target_dir => $preprocessing_dir . "/tDRmapper",
      perlFile   => "runtDRmapper.pl",
      option     => $def->{tDRmapper} . " " . $def->{tDRmapper_fasta},
      source_ref => "fastqfiles",
      output_ext => "_clipped_identical.fastq.hq_cs",
      sh_direct  => 1,
      pbs        => {
        "email"    => $def->{email},
        "nodes"    => "1:ppn=1",
        "walltime" => "1",
        "mem"      => "10gb"
      },
    };
    push @individual, ("tDRmapper");
  }

  #print Dumper($config);
  $config->{"fastq_len"} = {
    class      => "CQS::FastqLen",
    perform    => 1,
    target_dir => $preprocessing_dir . "/fastq_len",
    option     => "",
    source_ref => $len_ref,
    cqstools   => $def->{cqstools},
    sh_direct  => 1,
    cluster    => $cluster,
    pbs        => {
      "email"    => $def->{email},
      "nodes"    => "1:ppn=1",
      "walltime" => "24",
      "mem"      => "20gb"
    },
  };
  $config->{"fastq_len_vis"} = {
    class                    => "CQS::UniqueR",
    perform                  => 1,
    target_dir               => $preprocessing_dir . "/fastq_len",
    rtemplate                => "countTableVisFunctions.R,fastqLengthVis.R",
    output_file              => ".lengthDistribution",
    output_file_ext          => ".csv",
    parameterSampleFile1_ref => [ "fastq_len", ".len\$" ],
    parameterSampleFile2     => $groups,
    sh_direct                => 1,
    pbs                      => {
      "email"    => $def->{email},
      "nodes"    => "1:ppn=1",
      "walltime" => "1",
      "mem"      => "10gb"
    },
  };
  push @individual, ("fastq_len");
  push @summary,    ("fastq_len_vis");

  my $preparation = {
    identical => {
      class      => "CQS::FastqIdentical",
      perform    => 1,
      target_dir => $preprocessing_dir . "/identical",
      option     => "-l " . $def->{min_read_length},
      source_ref => $source_ref,
      cqstools   => $def->{cqstools},
      extension  => "_clipped_identical.fastq.gz",
      sh_direct  => 1,
      cluster    => $cluster,
      pbs        => {
        "email"    => $def->{email},
        "nodes"    => "1:ppn=1",
        "walltime" => "24",
        "mem"      => "20gb"
      },
    },
    identical_check_cca => {
      class              => "SmallRNA::TGIRTCheckCCA",
      perform            => 1,
      target_dir         => $preprocessing_dir . "/identical_check_cca",
      option             => "",
      source_ref         => [ 'identical', '.fastq.gz$' ],
      untrimmedFastq_ref => "files",
      cqs_tools          => $def->{cqstools},
      sh_direct          => 0,
      pbs                => {
        "email"    => $def->{email},
        "nodes"    => "1:ppn=1",
        "walltime" => "72",
        "mem"      => "10gb"
      },
    },
    identical_sequence_count_table => {
      class      => "CQS::SmallRNASequenceCountTable",
      perform    => 1,
      target_dir => $class_independent_dir . "/identical_sequence_count_table",
      option     => "--maxExtensionBase $max_sequence_extension_base -n $top_read_number --exportFastaNumber $top_read_number",
      source_ref => [ "identical", ".dupcount\$" ],
      cqs_tools  => $def->{cqstools},
      suffix     => "_sequence",
      sh_direct  => 1,
      cluster    => $cluster,
      groups     => $groups,
      pairs      => $pairs,
      pbs        => {
        "email"    => $def->{email},
        "nodes"    => "1:ppn=1",
        "walltime" => "10",
        "mem"      => "10gb"
      },
    },
  };

  push @individual, ("identical");
  push @summary,    ("identical_sequence_count_table");

  if ( $hasNTA && $def->{consider_tRNA_NTA} ) {
    $preparation->{identical_check_cca} = {
      class              => "SmallRNA::tRNACheckCCA",
      perform            => 1,
      target_dir         => $preprocessing_dir . "/identical_check_cca",
      option             => "",
      source_ref         => [ 'identical', '.fastq.gz$' ],
      untrimmedFastq_ref => "files",
      cqs_tools          => $def->{cqstools},
      sh_direct          => 0,
      pbs                => {
        "email"    => $def->{email},
        "nodes"    => "1:ppn=1",
        "walltime" => "72",
        "mem"      => "10gb"
      },
    };
    push @individual, ("identical_check_cca");
  }

  if ( $def->{special_sequence_file} ) {
    $config->{"special_sequence_count_table"} = {
      class                    => "CQS::ProgramWrapper",
      perform                  => 1,
      interpretor              => "python",
      program                  => "../SmallRNA/findSequence.py",
      target_dir               => $class_independent_dir . "/special_sequence_count_table",
      option                   => "",
      parameterSampleFile1_ref => [ "identical", ".dupcount\$" ],
      parameterFile1           => $def->{special_sequence_file},
      sh_direct                => 1,
      output_ext               => ".special_sequence.tsv",
      pbs                      => {
        "email"    => $def->{email},
        "nodes"    => "1:ppn=1",
        "walltime" => "10",
        "mem"      => "10gb"
      },
    };
    push @summary, ("special_sequence_count_table");
  }

  if ($blast_top_reads) {
    $preparation->{"identical_sequence_top${top_read_number}_contig_blast"} = {
      class      => "Blast::Blastn",
      perform    => 1,
      target_dir => $class_independent_dir . "/identical_sequence_top${top_read_number}_contig_blast",
      option     => "",
      source_ref => [ "identical_sequence_count_table", "sequence.count.fasta\$" ],
      sh_direct  => 0,
      localdb    => $blast_localdb,
      cluster    => $cluster,
      pbs        => {
        "email"    => $def->{email},
        "nodes"    => "1:ppn=" . $def->{max_thread},
        "walltime" => "72",
        "mem"      => "40gb"
      },
    };
    $preparation->{"identical_sequence_top${top_read_number}_read_blast"} = {
      class      => "Blast::Blastn",
      perform    => 1,
      target_dir => $class_independent_dir . "/identical_sequence_top${top_read_number}_read_blast",
      option     => "",
      source_ref => [ "identical_sequence_count_table", ".read.count.fasta\$" ],
      sh_direct  => 0,
      localdb    => $blast_localdb,
      cluster    => $cluster,
      pbs        => {
        "email"    => $def->{email},
        "nodes"    => "1:ppn=" . $def->{max_thread},
        "walltime" => "72",
        "mem"      => "40gb"
      },
    };
    $preparation->{"identical_sequence_top${top_read_number}_minicontig_blast"} = {
      class      => "Blast::Blastn",
      perform    => 1,
      target_dir => $class_independent_dir . "/identical_sequence_top${top_read_number}_minicontig_blast",
      option     => "",
      source_ref => [ "identical_sequence_count_table", ".minicontig.count.fasta\$" ],
      sh_direct  => 0,
      localdb    => $blast_localdb,
      cluster    => $cluster,
      pbs        => {
        "email"    => $def->{email},
        "nodes"    => "1:ppn=" . $def->{max_thread},
        "walltime" => "72",
        "mem"      => "40gb"
      },
    };
  }

  if ($hasNTA) {
    my $ccaaOption = $def->{consider_tRNA_NTA} ? "--ccaa" : "--no-ccaa";
    $preparation->{identical_NTA} = {
      class      => "SmallRNA::FastqSmallRnaNTA",
      perform    => 1,
      target_dir => $preprocessing_dir . "/identical_NTA",
      option     => $ccaaOption . " -l " . $def->{min_read_length},
      source_ref => [ "identical", ".fastq.gz\$" ],
      cqstools   => $def->{cqstools},
      extension  => "_clipped_identical_NTA.fastq.gz",
      sh_direct  => 1,
      cluster    => $cluster,
      pbs        => {
        "email"    => $def->{email},
        "nodes"    => "1:ppn=1",
        "walltime" => "24",
        "mem"      => "20gb"
      },
    };
    push @individual, ("identical_NTA");
  }

  $config = merge( $config, $preparation );

  return ( $config, \@individual, \@summary, $cluster, $source_ref, $preprocessing_dir, $class_independent_dir );
}

1;
