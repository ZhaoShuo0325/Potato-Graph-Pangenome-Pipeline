#!/bin/bash
HOME="/public/home/zhaoshuo/work1"
LIST="$HOME/merge_test/00_data/real.txt"
CHR="$HOME/merge_test/00_data/chrs.txt"
FQ_DIR="$HOME/simulation/varsim_out"
GRAPH_DIR="$HOME/merge_test/02_graph/01_merge"
SAMPLE_FILE="$HOME/merge_test/02_graph/01_merge/genotyping/sample.cfg"

for chr in $(cat $CHR); do
OUT_DIR="$HOME/merge_test/02_graph/01_merge/genotyping/${chr}"
mkdir -p \$OUT_DIR
cd \$OUT_DIR
varigraph genotype -t 128 \
                   --load-graph $GRAPH_DIR/${chr}_graph.bin \
                   -s $SAMPLE_FILE \
                   --use-depth \
                   --sv \
                   -n 12
done

# varigraph 生成的 vcf.gz 不是 bgzip 压缩格式，需要手动修改

#for i in {01..12}; do
#    echo "正在修复 chr${i} 目录..."
#    for f in chr${i}/*.vcf.gz; do
#        zcat "$f" | bgzip -c > "${f}.tmp" && mv "${f}.tmp" "$f"
#        tabix -f -p vcf "$f"
#    done
#done
