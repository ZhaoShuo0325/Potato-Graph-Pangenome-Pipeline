#!/bin/bash
d=5 #测序深度
HOME="/public/home/zhaoshuo/work1"
REF="$HOME/data/reference/DM8.1_genome.ori.chr.fa"
PREP_DIR="$HOME/merge_test/02_graph/04_vg_merge/prep"
FQ_DIR="$HOME/data/simulated/short_reads"
CHR="$HOME/merge_test/00_data/chrs.txt"
LIST="$HOME/merge_test/00_data/real.txt"
OUT_DIR="$HOME/merge_test/02_graph/04_vg_merge/giraffe"

for chr in $(cat $CHR); do
GBZ="$PREP_DIR/vg_merge_$chr.gbz"
DIST="$PREP_DIR/vg_merge_$chr.dist"
MIN="$PREP_DIR/vg_merge_$chr.min"
ZIP="$PREP_DIR/vg_merge_$chr.zipcodes"
LIST="$HOME/merge_test/00_data/real.txt"
OUT="$OUT_DIR/giraffe_d${d}"
mkdir -p \$OUT
for sample in \$(cat \$LIST); do
vg giraffe -t 128 \
        -Z \$GBZ \
        -d \$DIST \
        -m \$MIN \
        -z \$ZIP \
        -f $FQ_DIR/\${sample}_d${d}_PE1.fq.gz \
        -f $FQ_DIR/\${sample}_d${d}_PE2.fq.gz \
        -o gam > \$OUT/\${sample}_${chr}_giraffe.gam
done
done
