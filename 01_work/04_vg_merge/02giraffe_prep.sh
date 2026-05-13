#!/bin/bash
HOME="/public/home/zhaoshuo/work1"
REF="$HOME/data/reference/DM8.1_genome.ori.chr.fa"
VG_DIR="$HOME/merge_test/02_graph/04_vg_merge"
VCF_DIR="$HOME/merge_test/00_data/04_mergeSV"
CHR="$HOME/merge_test/00_data/chrs.txt"
OUT_DIR="$HOME/merge_test/02_graph/04_vg_merge/prep"

for chr in $(cat $CHR); do
    sed "s/50/128/g" work.sh | \
    sed "s/edta/prep_$chr/g" | \
    sed "s/%j/prep_$chr/g" > prep_$chr.sh

cat >> prep_$chr.sh << EOF
PREFIX="vg_merge_${chr}"
VG="$VG_DIR/${chr}_graph.vg"
GBWT="$VG_DIR/${chr}.gbwt"
OUT="$OUT_DIR"
echo "[\$(date +'%H:%M:%S')] Step1: 构建 xg"
vg index -t 128 -x \$OUT/\${PREFIX}.xg \$VG

echo "[\$(date +'%H:%M:%S')] Step2: 构建 GBZ（用已有的 VCF GBWT）"
vg gbwt \
    --num-jobs 128 \
    -x \$OUT/\${PREFIX}.xg \
    \$GBWT \
    -g \$OUT/\${PREFIX}.gbz

echo "[\$(date +'%H:%M:%S')] 验证路径数"
vg gbwt -Z \$OUT/\${PREFIX}.gbz -c

echo "[\$(date +'%H:%M:%S')] Step3: dist index"
vg index -t 128 -j \$OUT/\${PREFIX}.dist \$OUT/\${PREFIX}.gbz

echo "[\$(date +'%H:%M:%S')] Step4: minimizer + zipcodes"
vg minimizer \
    -t 128 \
    -d \$OUT/\${PREFIX}.dist \
    -o \$OUT/\${PREFIX}.min \
    -z \$OUT/\${PREFIX}.zipcodes \
    \$OUT/\${PREFIX}.gbz

echo "[\$(date +'%H:%M:%S')] Step5: snarls"
vg snarls -t 128 \$OUT/\${PREFIX}.gbz > \$OUT/\${PREFIX}.snarls

echo "[\$(date +'%H:%M:%S')] 完成: \${PREFIX}"
ls -lh \$OUT/\${PREFIX}.*
EOF
sbatch prep_$chr.sh
done