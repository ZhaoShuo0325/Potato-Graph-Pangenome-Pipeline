#!/bin/bash
#SBATCH --partition=AMD_9A14
#SBATCH --mem=256G
#SBATCH --cpus-per-task=128
#SBATCH --job-name=prepatation
#SBATCH --output=%x.out
#SBATCH --error=%x.err

# 环境准备
# source ~/.bashrc
# conda activate paragraph_env

d=5 #测序深度
HOME="/public/home/zhaoshuo/work1"
FQ_DIR="$HOME/data/simulated/short_reads"
REF="$HOME/data/reference/DM8.1_genome.fasta"
OUT_DIR="$HOME/gt/paragraph/exp1/Sim_01_02_d${d}"

rm -rf $OUT_DIR
mkdir -p $OUT_DIR

# 建立参考基因组索引
if [ ! -f "${REF}.bwt" ]; then
    echo "Indexing reference..."
    bwa index $REF
    samtools faidx $REF
fi

SAMPLE_LIST="$OUT_DIR/samples.txt"
# 建立样本清单
echo -e "id\tpath\tdepth\tread length" > $SAMPLE_LIST

for SAMPLE in Sim_01 Sim_02; do

    SAMPLE_NAME="$SAMPLE"
    FQ1="$FQ_DIR/${SAMPLE}_d${d}_PE1.fq.gz"
    FQ2="$FQ_DIR/${SAMPLE}_d${d}_PE2.fq.gz"
    TMP_BAM="$OUT_DIR/${SAMPLE_NAME}.sorted.bam"

    # 运行 BWA MEM 比对
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- Run" $SAMPLE_NAME "BWA MEM -----"
    bwa mem -t 16 -R "@RG\tID:${SAMPLE}\tSM:${SAMPLE}\tPL:ILLUMINA" $REF $FQ1 $FQ2 | \
    samtools sort -@ 4 -o $TMP_BAM

    # 建立 BWA 索引
    samtools index $TMP_BAM

    echo -e "${SAMPLE}\t${TMP_BAM}\t${d}\t150" >> $SAMPLE_LIST
done
