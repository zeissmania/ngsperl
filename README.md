NGSPERL : A semi-automated framework for large scale next generation sequencing data analysis
==========
* [Introduction](#Introduction)
* [Download and install](#download)
* [Quick Start](#example)
* [Usage](#usage)
* [Report](#report)

<a name="Introduction"/>
# Introduction #
High-throughput sequencing technologies have been widely used in the research field, especially in cancer biology. With the huge amounts of sequencing data being generated, data analysis has become the bottle-neck of the research procedure. A lot of tools have been developed for different data types and different data analysis purposes while new tools are still being published every month. A software framework which not only supports large scale data analysis using the existing pipeline on cluster but can also easily replace/extend old modules in the pipeline will help solve the problem. We have designed and implemented NGSPERL, a semi-automated module-based framework, for high-throughput sequencing data analysis. Three major analysis pipelines with multiple tasks have been developed for RNA sequencing, exome sequencing, and small RNA sequencing data. The pipelines cover the tasks from raw data pre-processing, quality control, mapping, and comparison to report. Each task in the pipelines was developed as module. The module uses the output from the previous task in the pipeline as the input parameter to generate the corresponding portable batch system (PBS) scripts with other user-defined parameters. The module with such a trace-back design can be easily plugged into or unplugged from existing pipelines. The PBS scripts generated at each task can be submitted to cluster or run directly based on user choice. Multiple tasks can also be combined together as a single task to simplify the data analysis. Such a flexible framework will significantly accelerate the speed of large scale sequencing data analysis.

<a name="download"/>
# Download and install #
You can download NGSPERL package from [github](https://github.com/shengqh/ngsperl/). Assume you download the NGSPERL package to "/home/user/ngsperl", add "/home/user/ngsperl/lib" into your your perl library path.
  
<a name="example"/>
# Quick start

Here we show the most basic steps for a validation procedure. You need to create a target directory used to store the GEO data. Here, we assume the target directory is your work directory.

	library(DupChecker)
	geoDownload(datasets = c("GSE14333", "GSE13067", "GSE17538"), targetDir=getwd())
	datafile<-buildFileTable(rootDir=getwd(), filePattern="cel$")
	result<-validateFile(datafile)
	if(result$hasdup){
  		duptable<-result$duptable
  		write.csv(duptable, file="duptable.csv")
	}

<a name="usage"/>
# Usage
##GEO/ArrayExpress data download
Firstly, function geoDownload/arrayExpressDownload will download raw data from ncbi/EBI 
ftp server based on datasets user provided. Once the compressed raw data is downloaded, 
CEL files will be extracted from compressed raw data. 

If the download or decompress cost too much time in R environment, user may download 
the GEO/ArrayExpress raw data and decompress the data to individual CEL files using other 
tools. The reason that we expect the CEL file not compressed CEL file is the compressed 
files from same CEL file but by different compress softwares may have different MD5 fingerprint.

The following code will download two datasets from ArrayExpress system and three datasets 
from GEO system. It may cost a few minutes to a few hours based your network performance.

	library(DupChecker)

	#download from ArrayExpress system
	datatable<-arrayExpress(datasets = c("E-TABM-158", "E-TABM-43"), targetDir=getwd()))
	datatable

	#Or download from GEO system
	datatable<-geoDownload(datasets = c("GSE14333", "GSE13067", "GSE17538"), targetDir=getwd())
	datatable

The datatable is a data frame containing dataset name and how many CEL files 
in that dataset.

##Build file table

Secondly, function buildFileTable will try to find all files in the subdirectories 
under root directories user provided. The result data frame contains two columns, 
dataset and filename. Here, rootDir can also be an array of directories. 

	datafile<-buildFileTable(rootDir=getwd(), filePattern="cel$")
	datafile

##Validate file redundancy

The function validateFile will calculate MD5 fingerprint for each file in table and 
then check to see if any two files have same MD5 fingerprint. The files with same 
fingerprint will be treated as duplication. The function will return a table contains 
all duplicated files and datasets.

	result<-validateFile(datafile)
	if(result$hasdup){
  		duptable<-result$duptable
  		write.csv(duptable, file="duptable.csv")
	}

<a name="report"/>
#Report
Table 1. Illustration of summary table generated by DupChecker for duplication among GSE13067, GSE14333, and GSE17538 data sets.

| MD5 | GSE13067(64/74) | GSE14333(231/290) | GSE17538(167/244) |
|-----|-----------------|-------------------|-------------------|
| 001ddd757f185561c9ff9b4e95563372 |	|	GSM358397.CEL |	GSM437169.CEL |
| 00b2e2290a924fc2d67b40c097687404 |	|	GSM358503.CEL |	GSM437210.CEL |
| 012ed9083b8f1b2ae828af44dbab29f0 |	GSM327335 |	GSM358620.CEL|	|
| 023c4e4f9ebfc09b838a22f2a7bdaa59 |	|	GSM358441.CEL |	GSM437117.CEL |




