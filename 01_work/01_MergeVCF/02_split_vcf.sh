#!/bin/bash
HOME="/public/home/zhaoshuo/work1"
LIST="$HOME/01_work/data/1M_PAV/list.txt"
VCF="$HOME/01_work/data/1M_PAV"
OUT_DIR="$HOME/01_work/data/1M_PAV/split_vcf"
CHR="$HOME/01_work/data/1M_PAV/split_vcf/chrs.txt"

for SAMPLE in $(cat $LIST); do
    for CHR in \$(cat \${CHR}); do
        bcftools view "$VCF/${SAMPLE}.norm.vcf.gz" "\${CHR}" -Oz -o "$OUT_DIR/${SAMPLE}.\${CHR}.vcf.gz"
        tabix -p vcf "$OUT_DIR/${SAMPLE}.\${CHR}.vcf.gz"
    done
done
