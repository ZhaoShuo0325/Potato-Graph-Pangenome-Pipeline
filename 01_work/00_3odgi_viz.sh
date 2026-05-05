#!/bin/bash

sed 's/50/128/g' work.sh | \
sed 's/256G/256G/g' | \
sed 's/edta/viz/g' | \
sed 's/%j/viz/g' > viz.sh

cat >> viz.sh << 'HEREDOC' 
HOME="/public/home/zhaoshuo/work1"
OG="$HOME/01_work/00_pggb/00_pggb_output/group60.chr01.fa.gz.c325321.7608fc1.877f7d9.smooth.final.og"
OUT_DIR="$HOME/01_work/00_pggb/00_pggb_output/02_viz"
PREFIX="group60_chr01"

x=8000
y=1000
a=10
t=64
LOG_FILE="$OUT_DIR/viz_progress.log"

# color by nucl pos in the path
odgi viz -i $OG -t $t -o $OUT_DIR/${PREFIX}_pos_multiqc.png -x $x -y $y -a $a -u -d -P -I "Consensus_" 2> >(tee -a $LOG_FILE)
# color by mean depth
odgi viz -i $OG -t $t -o $OUT_DIR/${PREFIX}_depth_multiqc.png -x $x -y $y -a $a -m -P -I "Consensus_" 2> >(tee -a $LOG_FILE)
# color by mean inversion rate
odgi viz -i $OG -t $t -o $OUT_DIR/${PREFIX}_inv_multiqc.png -x $x -y $y -a $a -z -P -I "Consensus_" 2> >(tee -a $LOG_FILE)
# stats
odgi stats -t $t -S -i $OG > $OUT_DIR/${PREFIX}_odgi_stats.tsv 2> >(tee -a $LOG_FILE)
HEREDOC
sbatch viz.sh