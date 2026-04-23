#!/bin/bash
#SBATCH --partition=AMD_9A14
#SBATCH --mem=256G
#SBATCH --cpus-per-task=128
#SBATCH --job-name=count_kmers
#SBATCH --output=%x.out
#SBATCH --error=%x.err

# 环境准备
# source ~/.bashrc
# conda activate bt_env

d=5 #测序深度
HOME="/public/home/zhaoshuo/work1"
FQ_DIR="$HOME/data/simulated/short_reads"
OUT_DIR="$HOME/gt/bayestyper/exp1/Sim_01_02_d${d}"
KMC_TMP="$OUT_DIR/tmp_kmc"

rm -rf $OUT_DIR
mkdir -p $OUT_DIR
mkdir -p $KMC_TMP
cd $OUT_DIR
# 运行 kmc 生成 Bloom Filter
for SAMPLE in Sim_01 Sim_02; do
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- Running kmc for ${SAMPLE}... -----"
    LIST="${SAMPLE}.lst"
    echo "$FQ_DIR/${SAMPLE}_d${d}_PE1.fq.gz" > $LIST
    echo "$FQ_DIR/${SAMPLE}_d${d}_PE2.fq.gz" >> $LIST
    kmc -k31 -ci1 -t64 -m128 \
        @$LIST \
        $OUT_DIR/${SAMPLE}_kmc \
        $KMC_TMP
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- Generating Bloom Filter for ${SAMPLE}... -----"
    bayesTyperTools makeBloom -k ${SAMPLE}_kmc -p 16
    rm -rf $LIST
done

rm -rf $KMC_TMP
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- All Done! -----"