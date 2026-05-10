#!/bin/bash
HOME="/public/home/zhaoshuo/work1"
LIST="$HOME/merge_test/00_data/real.txt"
CHR="$HOME/merge_test/00_data/chrs.txt"
CHR_DIR="$HOME/merge_test/02_graph/01_merge/genotyping"
RESULT_DIR="$HOME/merge_test/02_graph/01_merge/genotyping/results"
for sample in $(cat $LIST); do
    sed "s/50/128/g" work.sh | \
    sed "s/edta/combine_$sample/g" | \
    sed "s/%j/combine_$sample/g" > combine_$sample.sh
FILES=$(sed "s|^|$CHR_DIR/|; s|$|/${sample}.varigraph.vcf.gz|" $CHR | tr '\n' ' ')
cat >> combine_$sample.sh << EOF
bcftools concat $FILES -a -O z -o "$RESULT_DIR/${sample}.combined.vcf.gz"
    tabix -p vcf "$RESULT_DIR/${sample}.combined.vcf.gz"

EOF
sbatch combine_$sample.sh
done
