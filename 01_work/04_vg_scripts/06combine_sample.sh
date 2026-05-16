#!/bin/bash
d=5
HOME="/public/home/zhaoshuo/work1"
LIST="$HOME/merge_test/00_data/real.txt"
CHR_DIR="$HOME/merge_test/02_graph/04_vg_merge/giraffe/giraffe_d${d}/vg_call/results"
RESULT_DIR="$HOME/merge_test/02_graph/04_vg_merge/giraffe/giraffe_d${d}/vg_call/results"
for sample in $(cat $LIST); do
    sed "s/50/128/g" work.sh | \
    sed "s/edta/combine_$sample/g" | \
    sed "s/%j/combine_$sample/g" > combine_$sample.sh
cat >> combine_$sample.sh << EOF
CHR="$HOME/merge_test/00_data/chrs.txt"
VCF_LIST=""
for chr in \$(cat \$CHR); do
FILE="$CHR_DIR/${sample}_\${chr}.raw.vcf"
VCF_LIST="\$VCF_LIST \$FILE"
done
bcftools concat \$VCF_LIST | \
bcftools sort -O z -o "$RESULT_DIR/${sample}.combined.vcf.gz"
tabix -p vcf "$RESULT_DIR/${sample}.combined.vcf.gz"
EOF
sbatch combine_$sample.sh
done
