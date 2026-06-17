#!/bin/bash
HOME="/public/home/zhaoshuo/work1"
REF="$HOME/data/reference/DM8.1_genome.ori.chr.fa"
VCF_DIR="$HOME/merge_test/00_data/03_splitSV"
CHR="$HOME/merge_test/00_data/chrs.txt"
OUT_DIR="$HOME/merge_test/01_dedupSV/03_survivor"


for chr in $(cat $CHR); do
    sed "s/50/25/g" work.sh | \
    sed "s/edta/survivor_$chr/g" | \
    sed "s/%j/survivor_$chr/g" > survivor_$chr.sh

cat >> survivor_$chr.sh << EOF
LIST="$HOME/merge_test/00_data/real.txt"
cd $OUT_DIR
for s in \$(cat \$LIST); do
    zcat $VCF_DIR/\${s}.${chr}.vcf.gz > \${s}.${chr}.tmp.vcf
    echo "\${s}.${chr}.tmp.vcf" >> ${chr}_vcf_list.txt
done
SURVIVOR merge ${chr}_vcf_list.txt 1000 1 1 1 0 50 ${chr}.survivor_tmp.vcf
bcftools sort ${chr}.survivor_tmp.vcf -Oz -o ${chr}_survivor.vcf.gz
tabix -f -p vcf ${chr}_survivor.vcf.gz
rm ${chr}_vcf_list.txt ${chr}.survivor_tmp.vcf 
EOF
sbatch survivor_$chr.sh
done
