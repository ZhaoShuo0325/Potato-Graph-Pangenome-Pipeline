#!/bin/bash
HOME="/public/home/zhaoshuo/work1"
LIST="$HOME/merge_test/00_data/real.txt"
CHR="$HOME/merge_test/00_data/chrs.txt"
FQ_DIR="$HOME/simulation/varsim_out"
GRAPH_DIR="$HOME/merge_test/02_graph/01_merge"
SAMPLE_FILE="$HOME/merge_test/02_graph/01_merge/genotyping/sample.cfg"
for chr in $(cat $CHR); do
    sed "s/50/128/g" work.sh | \
    sed "s/edta/genotyping_$chr/g" | \
    sed "s/%j/genotyping_$chr/g" > genotyping_$chr.sh

cat >> genotyping_$chr.sh << EOF
OUT_DIR="$HOME/merge_test/02_graph/01_merge/genotyping/${chr}"
mkdir -p \$OUT_DIR
cd \$OUT_DIR
varigraph genotype -t 128 \
                   --load-graph $GRAPH_DIR/${chr}_graph.bin \
                   -s $SAMPLE_FILE \
                   --use-depth \
                   --sv \
                   -n 12
EOF
sbatch genotyping_$chr.sh
done
