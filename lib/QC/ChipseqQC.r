options(bitmapType='cairo')

args = commandArgs(trailingOnly = TRUE)

library(ChIPQC)

configFile=args[1]
annotationName=args[2]
chromosomes=args[3]

cat("configFile=", configFile, "\n")
cat("annotationName=", annotationName, "\n")
cat("chromosomes=", chromosomes, "\n")

if(!is.na(chromosomes)){
  chromosomes = unlist(strsplit(chromosomes, split=','))
}else{
  chromosomes = NULL
} 

experiment <- read.table(configFile, sep="\t", header=T)

qcresult = ChIPQC(experiment, annotation = annotationName, chromosomes=chromosomes)

ChIPQCreport(qcresult)
