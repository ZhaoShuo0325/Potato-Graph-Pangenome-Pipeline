#!/bin/bash
d=5 #测序深度
HOME="/public/home/zhaoshuo/work1"
REF="$HOME/data/reference/DM8.1_genome.ori.chr.fa"
GAM_DIR="$HOME/merge_test/02_graph/04_vg_merge/giraffe/giraffe_d${d}"
XG_DIR="$HOME/merge_test/02_graph/04_vg_merge/prep"
CHR="$HOME/merge_test/00_data/chrs.txt"
OUT_DIR="$HOME/merge_test/02_graph/04_vg_merge/giraffe/giraffe_d${d}/vg_call"

for chr in $(cat $CHR); do
    sed "s/50/128/g" work.sh | \
    sed "s/edta/pack_$chr/g" | \
    sed "s/%j/pack_$chr/g" > pack_$chr.sh

cat >> pack_$chr.sh << EOF
LIST="$HOME/merge_test/00_data/real.txt"
for SAMPLE in \$(cat \$LIST); do
    XG="$XG_DIR/vg_merge_${chr}.xg"
    GAM="$GAM_DIR/\${SAMPLE}_${chr}_giraffe.gam"
    vg pack -t 128 -e -Q 5 \
        -x \$XG \
        -g \$GAM \
        -o "$OUT_DIR/\${SAMPLE}_${chr}.pack"
done
EOF
sbatch pack_$chr.sh
done
