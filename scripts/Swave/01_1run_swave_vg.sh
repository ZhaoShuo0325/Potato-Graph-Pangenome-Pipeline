#!/bin/bash
#SBATCH --partition=AMD_9A14
#SBATCH --mem=256G
#SBATCH --cpus-per-task=128
#SBATCH --job-name=run_swave
#SBATCH --output=%x.out
#SBATCH --error=%x.err

# source ~/.bashrc
# conda activate Swave-env

HOME="/public/home/zhaoshuo/work1"
REF="$HOME/data/reference/DM8.1_genome.fasta"
GFA="/public/home/zhaoshuo/work1/graph/vg/exp1/Sim_01_02/Sim_01_02_graph.gfa" # 输入的GFA文件
VCF="$HOME/graph/vg/exp1/Sim_01_02/deconstruct/Sim_01_02_50bp.vcf.gz"
SAMPLE_DIR="$HOME/data/simulated/genomes"
OUT_DIR="$HOME/graph/swave/exp1/Sim_01_02_swave_vg"
SWAVE="/public/home/zhaoshuo/software/Swave/Swave.py"

rm -rf $OUT_DIR
mkdir -p $OUT_DIR
cd $OUT_DIR

# 准备 tsv 文件
SAMPLE_TSV="$OUT_DIR/samples.tsv"
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- Writing sample.txt -----"
echo -e "DM8\t$REF" > $SAMPLE_TSV
for i in {01..02}; do
    echo -e "Sim_${i}\t$SAMPLE_DIR/Sim_${i}_haplotype1.fasta\t$SAMPLE_DIR/Sim_${i}_haplotype2.fasta" >> $SAMPLE_TSV
done

# 运行 Swave call 模块
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- Starting Swave Genotyping -----"

python $SWAVE call \
    --input_path $SAMPLE_TSV \
    --ref_path $REF \
    --gfa_source pggb \
    --gfa_path $GFA \
    --decomposed_vcf $VCF \
    --output_path $OUT_DIR \
    --thread_num 128

echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- Swave Call Finished -----"
