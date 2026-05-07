#!/bin/bash
#SBATCH --partition=AMD_9A14
#SBATCH --mem=50G
#SBATCH --cpus-per-task=25
#SBATCH --job-name=short_reads
#SBATCH --output=%x.out
#SBATCH --error=%x.err

# source ~/.bashrc
# conda activate art_env

HOME="/public/home/zhaoshuo/work1"
GENOMES_DIR="$HOME/data/simulated/genomes"
OUT_DIR="$HOME/data/simulated/short_reads"

mkdir -p $OUT_DIR

f=5 #测序深度

for i in {01..02};do
    SAMPLE_FASTA="$GENOMES_DIR/Sim_${i}.fasta"
    art_illumina -ss HS25 -sam -i $SAMPLE_FASTA -p -l 150 -f $f -m 200 -s 10 -o $OUT_DIR/Sim_${i}_d${f}_PE
done

pigz -p 24 $OUT_DIR/*.fq