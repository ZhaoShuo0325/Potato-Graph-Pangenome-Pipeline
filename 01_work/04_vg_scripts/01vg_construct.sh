#!/bin/bash
HOME="/public/home/zhaoshuo/work1"
REF="$HOME/data/reference/DM8.1_genome.ori.chr.fa"
VCF_DIR="$HOME/merge_test/00_data/04_mergeSV"
CHR="$HOME/merge_test/00_data/chrs.txt"
OUT_DIR="$HOME/merge_test/02_graph/04_vg_merge"

for chr in $(cat $CHR); do
vg construct -t 128 \
    -r $REF \
    -R ${chr} \
    -v $VCF_DIR/${chr}_merged.vcf.gz \
    -a -p > $OUT_DIR/${chr}_graph.vg

vg view -g $OUT_DIR/${chr}_graph.vg > $OUT_DIR/${chr}_graph.gfa
vg gbwt --num-jobs 128 \
    -x "$OUT_DIR/${chr}_graph.vg" \
    -v "$VCF_DIR/${chr}_merged.vcf.gz" \
    -o "$OUT_DIR/${chr}.gbwt" \
    --vcf-variants \
    --progress
done
