#!/bin/bash
#SBATCH --partition=AMD_9A14
#SBATCH --mem=256G
#SBATCH --cpus-per-task=128
#SBATCH --job-name=01run_mc
#SBATCH --output=%x.out
#SBATCH --error=%x.err

# source ~/.bashrc
# conda activate mc_env

HOME="/public/home/zhaoshuo/work1"
REF="$HOME/data/reference/DM8.1_genome.fasta"
ORI_DIR="$HOME/data/simulated/genomes" # 样本基因组路径
OUT_DIR="$HOME/graph/mc/exp1/sim_01_02_mc"
SAMPLE_LIST="Sim_01_h1 Sim_01_h2 Sim_02_h1 Sim_02_h2 DM8.1_genome"
JS="$OUT_DIR/js_sim"
SAMPLE_FILE="./sample.txt" 

rm  -rf $OUT_DIR $SAMPLE_FILE
mkdir -p $OUT_DIR
# 将样本名称和路径写入sample.txt文件
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- Writing sample.txt -----"
echo -e "DM8\t$REF" > $SAMPLE_FILE
for i in {01..02}; do
    for h in 1 2; do
        echo -e "Sim_${i}_${h} $ORI_DIR/Sim_${i}_haplotype${h}.fasta" >> $SAMPLE_FILE
    done
done
# 运行 Minigraph-Cactus
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- Running Minigraph-Cactus -----"
CHRS=$(for i in $(seq 12); do printf "chr%02d " $i; done)

cactus-pangenome $JS $SAMPLE_FILE \
    --outDir $OUT_DIR \
    --outName sim_01_02_mc \
    --reference DM8 \
    --refContigs $CHRS \
    --otherContig chrOther \
    --gfa full \
    --gbz full \
    --odgi full \
    --giraffe full \
    --vcf \
    --vcfbub 1000000 \
    --workDir $OUT_DIR \
    --mapCores 32 \
    --consCores 32 \
    --indexCores 32 \
    --binariesMode local \
    --logInfo

sync
sleep 5
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- Minigraph-Cactus finished -----"
