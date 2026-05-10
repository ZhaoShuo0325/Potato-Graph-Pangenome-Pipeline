#!/bin/bash
HOME="/public/home/zhaoshuo/work1"
REF="$HOME/data/reference/DM8.1_genome.ori.chr.fa"
VCF_DIR="$HOME/merge_test/00_data/04_mergeSV"
CHR="$HOME/merge_test/00_data/chrs.txt"
OUT_DIR="$HOME/merge_test/02_graph/01_merge"
for chr in $(cat $CHR); do
    sed "s/50/128/g" work.sh | \
    sed "s/edta/merge_graph_$chr/g" | \
    sed "s/%j/merge_graph_$chr/g" > merge_graph_$chr.sh


cat >> merge_graph_$chr.sh << EOF
varigraph construct -t 128 -r $REF -v $VCF_DIR/${chr}_merged.vcf.gz --save-graph $OUT_DIR/${chr}_graph.bin
EOF
sbatch merge_graph_$chr.sh
done