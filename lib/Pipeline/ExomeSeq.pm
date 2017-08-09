#!/usr/bin/perl
package Pipeline::ExomeSeq;

use strict;
use warnings;
use CQS::FileUtils;
use CQS::SystemUtils;
use CQS::ConfigUtils;
use CQS::ClassFactory;
use Pipeline::PipelineUtils;
use Pipeline::Preprocession;
use Data::Dumper;
use Hash::Merge qw( merge );

require Exporter;
our @ISA = qw(Exporter);

our %EXPORT_TAGS = ( 'all' => [qw(performExomeSeq performExomeSeqTask)] );

our @EXPORT = ( @{ $EXPORT_TAGS{'all'} } );

our $VERSION = '0.01';

sub initializeDefaultOptions {
  my $def = shift;
  initDefaultValue( $def, "subdir", 0 );

  initDefaultValue( $def, "sra_to_fastq", 0 );

  initDefaultValue( $def, "aligner", "bwa" );
  if ( $def->{aligner} eq "bwa" ) {
    initDefaultValue( $def, "bwa_option", "" );
  }

  initDefaultValue( $def, "perform_gatk_callvariants",   0 );
  initDefaultValue( $def, "gatk_callvariants_vqsr_mode", 1 );

  initDefaultValue( $def, "perform_multiqc", 1 );

  return $def;
}

sub getConfig {
  my ($def) = @_;
  $def->{VERSION} = $VERSION;

  my $target_dir = $def->{target_dir};
  create_directory_or_die($target_dir);

  $def = initializeDefaultOptions($def);

  my ( $config, $individual, $summary, $source_ref, $preprocessing_dir ) = getPreprocessionConfig($def);
  my $step2 = [];

  my $email    = getValue( $def, "email" );
  my $cqstools = getValue( $def, "cqstools" );

  my $bam_ref;
  my $fasta;
  if ( $def->{aligner} eq "bwa" ) {
    $fasta = getValue( $def, "bwa_fasta" );
    $config->{ $def->{aligner} } = {
      class                 => "Alignment::BWA",
      perform               => 1,
      target_dir            => "${target_dir}/" . getNextFolderIndex($def) . $def->{aligner},
      option                => getValue( $def, "bwa_option" ),
      bwa_index             => $fasta,
      source_ref            => $source_ref,
      output_to_same_folder => 1,
      picard_jar            => getValue( $def, "picard_jar" ),
      mark_duplicates       => 1,
      sh_direct             => 0,
      pbs                   => {
        "email"    => $email,
        "nodes"    => "1:ppn=8",
        "walltime" => "72",
        "mem"      => "40gb"
      },
    };
    $bam_ref = [ "bwa", ".bam\$" ];
  }
  else {
    die "Unknown alinger " . $def->{aligner};
  }

  push @$individual, ( $def->{aligner} );

  if ( $def->{perform_gatk_callvariants} ) {
    my $gatk_jar   = getValue( $def, "gatk_jar" );
    my $picard_jar = getValue( $def, "picard_jar" );
    my $dbsnp      = getValue( $def, "dbsnp" );
    my $mills      = $def->{mills};
    my $vcf = defined $mills ? [ $dbsnp, $mills ] : [$dbsnp];

    my $refine_name = $def->{aligner} . "_refine";
    $config->{$refine_name} = {
      class      => "GATK::Refine",
      perform    => 1,
      target_dir => "${target_dir}/$refine_name",
      option     => "-Xmx40g",

      #gatk_option => "--fix_misencoded_quality_scores",
      gatk_option              => "",
      fasta_file               => $fasta,
      source_ref               => $bam_ref,
      vcf_files                => $vcf,
      gatk_jar                 => $gatk_jar,
      picard_jar               => $picard_jar,
      sh_direct                => 0,
      slim_print_reads         => 1,
      samtools_baq_calibration => 0,
      sorted                   => 1,
      pbs                      => {
        "email"    => $email,
        "nodes"    => "1:ppn=1",
        "walltime" => "2",
        "mem"      => "40gb"
      },
    };
    push @$individual, ($refine_name);

    my $gvcf_name = $refine_name . "_hc_gvcf";
    $config->{$gvcf_name} = {
      class         => "GATK::HaplotypeCaller",
      perform       => 1,
      target_dir    => "${target_dir}/$gvcf_name",
      option        => "",
      source_ref    => $refine_name,
      java_option   => "",
      fasta_file    => $fasta,
      gatk_jar      => $gatk_jar,
      extension     => ".g.vcf",
      by_chromosome => 0,
      gvcf          => 1,
      sh_direct     => 0,
      pbs           => {
        "email"    => $email,
        "nodes"    => "1:ppn=8",
        "walltime" => "72",
        "mem"      => "40gb"
      },
    };
    push @$summary, ($gvcf_name);

    my $filter_name;
    if ( $def->{gatk_callvariants_vqsr_mode} ) {
      $filter_name = $gvcf_name . "_vqsr";
      $config->{$filter_name} = {
        class       => "GATK::VariantFilter",
        perform     => 1,
        target_dir  => "${target_dir}/$filter_name",
        option      => "",
        vqsr_mode   => 1,
        source_ref  => "$gvcf_name",
        java_option => "",
        fasta_file  => $fasta,
        dbsnp_vcf   => $dbsnp,
        hapmap_vcf  => $def->{hapmap},
        omni_vcf    => $def->{omni},
        g1000_vcf   => $def->{g1000},
        mills_vcf   => $mills,
        gatk_jar    => $gatk_jar,
        cqstools    => $cqstools,
        sh_direct   => 1,
        pbs         => {
          "email"    => $email,
          "nodes"    => "1:ppn=1",
          "walltime" => "72",
          "mem"      => "40gb"
        },
      };
    }
    else {
      $filter_name = $gvcf_name . "_hardfilter";

      $config->{$filter_name} = {
        class       => "GATK::VariantFilter",
        perform     => 1,
        target_dir  => "${target_dir}/$filter_name",
        option      => "",
        source_ref  => $gvcf_name,
        java_option => "",
        gatk_jar    => $gatk_jar,
        fasta_file  => $fasta,
        sh_direct   => 1,
        vqsr_mode   => 0,
        is_rna      => 0,
        pbs         => {
          "email"    => $email,
          "nodes"    => "1:ppn=1",
          "walltime" => "72",
          "mem"      => "40gb"
        },
      };
    }
    push @$summary, ($filter_name);

    my $annovar_name = $filter_name . "_annovar";
    $config->{$annovar_name} = {
      class      => "Annotation::Annovar",
      perform    => 1,
      target_dir => "${target_dir}/$annovar_name",
      source_ref => "$filter_name",
      option     => getValue( $def, "annovar_param" ),
      annovar_db => getValue( $def, "annovar_db" ),
      buildver   => getValue( $def, "annovar_buildver" ),
      sh_direct  => 1,
      isvcf      => 1,
      pbs        => {
        "email"    => $email,
        "nodes"    => "1:ppn=1",
        "walltime" => "2",
        "mem"      => "10gb"
      },
    };
    push @$summary, ($annovar_name);
  }

  if ( getValue( $def, "perform_multiqc" ) ) {
    addMultiQC( $config, $def, $summary, $target_dir, $target_dir );
  }
  $config->{"sequencetask"} = {
    class      => "CQS::SequenceTask",
    perform    => 1,
    target_dir => "${target_dir}/sequencetask",
    option     => "",
    source     => {
      step_1 => $individual,
      step_2 => $summary,
    },
    sh_direct => 0,
    pbs       => {
      "email"    => $email,
      "nodes"    => "1:ppn=8",
      "walltime" => "72",
      "mem"      => "40gb"
    },
  };

  return ($config);
}

sub performExomeSeq {
  my ( $def, $perform ) = @_;
  if ( !defined $perform ) {
    $perform = 1;
  }

  my $config = getConfig($def);

  if ($perform) {
    saveConfig( $def, $config );

    performConfig($config);
  }

  return $config;
}

sub performExomeSeqTask {
  my ( $def, $task ) = @_;
  my $config = getConfig($def);

  performTask( $config, $task );

  return $config;
}

1;
