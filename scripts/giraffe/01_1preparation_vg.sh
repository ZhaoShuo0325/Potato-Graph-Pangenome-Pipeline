#!/bin/bash
#SBATCH --partition=AMD_9A14
#SBATCH --mem=256G
#SBATCH --cpus-per-task=128
#SBATCH --job-name=preparation
#SBATCH --output=%x.out
#SBATCH --error=%x.err

# 环境准备
# source ~/.bashrc
# conda activate vg_env

HOME="/public/home/zhaoshuo/work1"
VG="$HOME/graph/vg/exp1/Sim_01_02/Sim_01_02_graph.vg"
VCF="$HOME/graph/vg/vcf_data/Sim_01_02_final.vcf.gz"
OUT_DIR="$HOME/gt/giraffe/exp1/data"
PREFIX="Sim_01_02_vg"
REF="$HOME/data/reference/DM8.1_genome.fasta"

rm -rf $OUT_DIR
mkdir -p $OUT_DIR

# 构建XG索引 用于vg call
echo "Building XG index for vg call"
vg index $VG -t 128 -L -x $OUT_DIR/${PREFIX}.xg
#构建GBWT和GBZ 用于vg giraffe
echo "Building GBWT and GBZ for vg giraffe"
vg gbwt --num-jobs 128 -x $OUT_DIR/${PREFIX}.xg -v $VCF -o $OUT_DIR/${PREFIX}.gbwt
vg gbwt --num-jobs 128 -x $OUT_DIR/${PREFIX}.xg $OUT_DIR/${PREFIX}.gbwt -g $OUT_DIR/${PREFIX}.gbz

# 构建距离索引, 种子索引和Snarl 用于vg giraffe
echo "Building distance index, seed index and snarl for vg giraffe"
vg index -t 128 -j $OUT_DIR/${PREFIX}.dist $OUT_DIR/${PREFIX}.gbz
vg minimizer -t 128 -d $OUT_DIR/${PREFIX}.dist -o $OUT_DIR/${PREFIX}.min -z $OUT_DIR/${PREFIX}.zipcodes $OUT_DIR/${PREFIX}.gbz
vg snarls -t 128 $OUT_DIR/${PREFIX}.xg > $OUT_DIR/${PREFIX}.snarls

echo "Done!"