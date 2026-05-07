#!/bin/bash
REF="/public/home/zhaoshuo/work1/data/reference/DM8.1_genome.ori.chr.fa"
for vcf in ../1M_PAV/*.vcf.gz; do
    bcftools norm --threads 32 -m -any -f $REF $vcf -Oz | bcftools sort -Oz -o "${vcf%.vcf.gz}.norm.vcf.gz"
done
ls *.norm.vcf.gz | xargs -I {} tabix -p vcf {}
ls *.norm.vcf.gz > vcf.list
