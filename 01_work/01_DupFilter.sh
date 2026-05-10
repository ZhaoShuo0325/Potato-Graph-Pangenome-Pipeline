#!/bin/bash
HOME="/public/home/zhaoshuo/work1"
REF="$HOME/data/reference/DM8.1_genome.ori.chr.fa"
VCF_DIR="$HOME/01_work/data/1M_PAV/merged_vcf"
CHR="$HOME/01_work/data/1M_PAV/split_vcf/chrs.txt"
OUT_DIR="$HOME/01_work/data/1M_PAV/merged_vcf/filtered"
RSCRIPT="./DupFilter.R"

for chr in $(cat $CHR); do
Rscript $RSCRIPT $VCF_DIR $chr $OUT_DIR
done
