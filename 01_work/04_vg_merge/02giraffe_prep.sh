#!/bin/bash
HOME="/public/home/zhaoshuo/work1"
REF="$HOME/data/reference/DM8.1_genome.ori.chr.fa"
VG_DIR="$HOME/merge_test/02_graph/04_vg_merge"
VCF_DIR="$HOME/merge_test/00_data/04_mergeSV"
CHR="$HOME/merge_test/00_data/chrs.txt"
OUT_DIR="$HOME/merge_test/02_graph/04_vg_merge/prep"

for chr in $(cat $CHR); do
PREFIX="vg_merge_${chr}"
VG="$VG_DIR/${chr}_graph.vg"
GBWT="$VG_DIR/${chr}.gbwt"
OUT="$OUT_DIR"

vg index -t 128 -x \$OUT/\${PREFIX}.xg \$VG

vg gbwt \
    --num-jobs 128 \
    -x \$OUT/\${PREFIX}.xg \
    \$GBWT \
    -g \$OUT/\${PREFIX}.gbz

vg gbwt -Z \$OUT/\${PREFIX}.gbz -c

vg index -t 128 -j \$OUT/\${PREFIX}.dist \$OUT/\${PREFIX}.gbz

vg minimizer \
    -t 128 \
    -d \$OUT/\${PREFIX}.dist \
    -o \$OUT/\${PREFIX}.min \
    -z \$OUT/\${PREFIX}.zipcodes \
    \$OUT/\${PREFIX}.gbz

vg snarls -t 128 \$OUT/\${PREFIX}.gbz > \$OUT/\${PREFIX}.snarls
done
