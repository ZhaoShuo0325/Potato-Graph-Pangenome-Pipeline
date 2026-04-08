#!/bin/bash
#SBATCH --partition=AMD_9A14
#SBATCH --mem=256G
#SBATCH --cpus-per-task=128
#SBATCH --job-name=deconstruct_vg
#SBATCH --output=%x.out
#SBATCH --error=%x.err

# source ~/.bashrc
# conda activate vg_env

HOME="/public/home/zhaoshuo/work1/graph/vg/exp1/Sim_01_02"
VG_FILE="$HOME/Sim_01_02_graph.vg"
OUT_PREFIX="Sim_01_02"
DECON_DIR="$HOME/deconstruct"
GBWT="$HOME/Sim_01_02.gbwt"

rm -rf "$DECON_DIR"
mkdir -p "$DECON_DIR"
cd "$DECON_DIR"

vg snarls -t 24 $VG_FILE > "$OUT_PREFIX".snarls
SNARLS="$DECON_DIR/$OUT_PREFIX.snarls"

vg paths -L -v "$VG_FILE" | grep -v "_alt_" | grep -v "Sim_" | tr -d '\r' > clean_ref_paths.txt
P_ARGS=$(sed 's/^/-p /' clean_ref_paths.txt | tr '\n' ' ')
vg deconstruct -t 128 -g "$GBWT" -r "$SNARLS" $P_ARGS "$VG_FILE" | \
bcftools view -s Sim_01,Sim_02 -Oz -o Sim_01_02_deconstruct.vcf.gz
bcftools index Sim_01_02_deconstruct.vcf.gz
bcftools stats Sim_01_02_deconstruct.vcf.gz > Sim_01_02_deconstruct.stats
