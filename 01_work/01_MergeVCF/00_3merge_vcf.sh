#!/bin/bash
HOME="/public/home/zhaoshuo/work1"
REF="$HOME/data/reference/DM8.1_genome.ori.chr.fa"
VCF="$HOME/01_work/data/1M_PAV/split_vcf"
OUT_DIR="$HOME/01_work/data/1M_PAV/merged_vcf"
CHR="$HOME/01_work/data/1M_PAV/split_vcf/chrs.txt"
for chr in $(cat $CHR); do
    sed "s/50/25/g" work.sh | \
    sed "s/256G/50G/g" | \
    sed "s/edta/$chr/g" | \
    sed "s/%j/$chr/g" > $chr.sh


cat >> $chr.sh << EOF
ls ${VCF}/*.${chr}.vcf.gz > ${OUT_DIR}/${chr}_vcf.list
MERGED_VCF=${OUT_DIR}/${chr}_merged.vcf.gz
bcftools merge -l ${OUT_DIR}/${chr}_vcf.list | \
bcftools norm -m -any -N | \
bcftools norm -d none -f $REF | \
bcftools sort | \
bgzip > \$MERGED_VCF
tabix -p vcf \$MERGED_VCF
EOF
sbatch $chr.sh
done