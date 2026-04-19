#!/bin/bash
#SBATCH --partition=AMD_9A14
#SBATCH --mem=256G
#SBATCH --cpus-per-task=128
#SBATCH --job-name=prepatation
#SBATCH --output=%x.out
#SBATCH --error=%x.err

# 环境准备
# source ~/.bashrc
# conda activate vg_env

HOME="/public/home/zhaoshuo/work1"
GFA="/public/home/zhaoshuo/work1/graph/pggb/exp2/nodup_01_02_total_p99_s10000_k47_G500_n5/nodup_01_02_total.fa.gz.5bf3b36.7608fc1.14b8b07.smooth.final.gfa" # 输入的GFA文件
OUT_DIR="$HOME/gt/giraffe/exp2/data"
PREFIX="nodup_01_02_PGGB"
rm -rf $OUT_DIR
mkdir -p $OUT_DIR

echo "1. Building GBZ..."
# 由于PGGB不存在参考基因组，需要手动设置DM8作为参考基因组
vg gbwt --num-jobs 128 --set-reference DM8 -G $GFA -g ${OUT_DIR}/${PREFIX}.gbz

echo "2. Building Distance Index..."
vg index -t 128 -j ${OUT_DIR}/${PREFIX}.dist ${OUT_DIR}/${PREFIX}.gbz

echo "3. Building Minimizer Index..."
vg minimizer -t 128 \
             -d ${OUT_DIR}/${PREFIX}.dist \
             -o ${OUT_DIR}/${PREFIX}.min \
             ${OUT_DIR}/${PREFIX}.gbz

echo "Index preparation complete!"

ls -lh ${OUT_DIR}/${PREFIX}.*
