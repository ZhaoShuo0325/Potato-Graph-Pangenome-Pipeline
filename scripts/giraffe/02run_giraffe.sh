#!/bin/bash
#SBATCH --partition=AMD_9A14
#SBATCH --mem=256G
#SBATCH --cpus-per-task=128
#SBATCH --job-name=run_giraffe
#SBATCH --output=%x.out
#SBATCH --error=%x.err

# 环境准备
# source ~/.bashrc
# conda activate vg_env

d=20 #测序深度
HOME="/public/home/zhaoshuo/work1"
GBZ="$HOME/gt/giraffe/exp1/data/Sim_01_02_PGGB.gbz"
DIST="$HOME/gt/giraffe/exp1/data/Sim_01_02_PGGB.dist"
MIN="$HOME/gt/giraffe/exp1/data/Sim_01_02_PGGB.min"
FQ_DIR="$HOME/data/simulated/short_reads"
OUT_DIR="$HOME/gt/giraffe/exp1/Sim_01_02_PGGB_giraffe_d${d}"

rm -rf $OUT_DIR
mkdir -p $OUT_DIR
SAMPLES="Sim_01 Sim_02"
# 运行 Giraffe
for SAMPLE in $SAMPLES; do
    echo "Running Giraffe for $SAMPLE"
    vg giraffe -t 128 \
        -Z $GBZ \
        -d $DIST \
        -m $MIN \
        -f $FQ_DIR/${SAMPLE}_d${d}_PE1.fq.gz \
        -f $FQ_DIR/${SAMPLE}_d${d}_PE2.fq.gz \
        -o gaf > $OUT_DIR/${SAMPLE}_giraffe.gaf
done
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- Giraffe finished -----"
