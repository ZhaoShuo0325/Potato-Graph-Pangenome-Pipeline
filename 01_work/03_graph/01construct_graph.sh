#!/bin/bash
HOME="/public/home/zhaoshuo/work1"
REF="$HOME/data/reference/DM8.1_genome.ori.chr.fa"
VCF_DIR="$HOME/merge_test/00_data/04_mergeSV"
CHR="$HOME/merge_test/00_data/chrs.txt"
OUT_DIR="$HOME/merge_test/02_graph/01_merge"

for chr in $(cat $CHR); do
varigraph construct -t 128 -r $REF -v $VCF_DIR/${chr}_merged.vcf.gz --save-graph $OUT_DIR/${chr}_graph.bin
done
