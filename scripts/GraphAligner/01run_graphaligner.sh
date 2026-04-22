#!/bin/bash
#SBATCH --partition=AMD_9A14
#SBATCH --mem=256G
#SBATCH --cpus-per-task=128
#SBATCH --job-name=run_graphaligner
#SBATCH --output=%x.out
#SBATCH --error=%x.err

# 环境准备
# source ~/.bashrc
# conda activate galigner_env

d=5 #测序深度
HOME="/public/home/zhaoshuo/work1"
VG="$HOME/graph/vg/exp1/Sim_01_02/Sim_01_02_graph.vg"
FQ_DIR="$HOME/data/simulated/short_reads"
OUT_DIR="$HOME/gt/graphaligner/exp1/Sim_01_02_vg_graphaligner_d${d}"

rm -rf $OUT_DIR
mkdir -p $OUT_DIR
SAMPLES="Sim_01 Sim_02"

# 运行 GraphAligner
for SAMPLE in $SAMPLES; do
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- Running GraphAligner for $SAMPLE -----"
    GraphAligner -g $VG \
                 -f $FQ_DIR/${SAMPLE}_d${d}_PE1.fq.gz \
                 -f $FQ_DIR/${SAMPLE}_d${d}_PE2.fq.gz \
                 -a $OUT_DIR/${SAMPLE}.gam \
                 -x vg \
                 -t 128 \
                 --verbose
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- Done with GraphAligner for $SAMPLE -----"                
done               
