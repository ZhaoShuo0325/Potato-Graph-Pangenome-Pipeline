#!/bin/bash
HOME="/public/home/zhaoshuo/work1"
LIST="$HOME/01_work/data/1M_PAV/list.txt"
VCF="$HOME/01_work/data/1M_PAV"
OUT_DIR="$HOME/01_work/data/1M_PAV/split_vcf"
for SAMPLE in $(cat $LIST); do
    sed "s/50/25/g" work.sh | \
    sed "s/256G/50G/g" | \
    sed "s/edta/$SAMPLE/g" | \
    sed "s/%j/$SAMPLE/g" > $SAMPLE.sh


cat >> $SAMPLE.sh << EOF
HOME="/public/home/zhaoshuo/work1"
CHR="$HOME/01_work/data/1M_PAV/split_vcf/chrs.txt"

for CHR in \$(cat \${CHR}); do
    bcftools view "$VCF/${SAMPLE}.norm.vcf.gz" "\${CHR}" -Oz -o "$OUT_DIR/${SAMPLE}.\${CHR}.vcf.gz"
    tabix -p vcf "$OUT_DIR/${SAMPLE}.\${CHR}.vcf.gz"
done
EOF
sbatch $SAMPLE.sh
done
