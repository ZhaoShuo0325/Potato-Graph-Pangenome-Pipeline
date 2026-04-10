#!/bin/bash
#SBATCH --partition=AMD_9A14
#SBATCH --mem=50G
#SBATCH --cpus-per-task=25
#SBATCH --job-name=run_sim
#SBATCH --output=%x.out
#SBATCH --error=%x.err

# source ~/.bashrc
# conda activate simit_env

HOME="/public/home/zhaoshuo"
SIMIT="$HOME/software/sim-it/Sim-it1.4.4.pl"
CONFIG_DIR="$HOME/work1/simulation/configs"
OUTPUT_DIR="$HOME/work1/simulation/output"

mkdir -p "$OUTPUT_DIR"

for i in $(seq -w 1 2);do
    HAP_NAME="nodup_hap0${i}" # 样本命名
    CONFIG_FILE="${CONFIG_DIR}/${HAP_NAME}_config.txt"
    HAP_OUTPUT="${OUTPUT_DIR}/${HAP_NAME}"

    mkdir -p "$HAP_OUTPUT"
    perl "$SIMIT" -c "$CONFIG_FILE" -o "$HAP_OUTPUT" > "$HAP_OUTPUT/sim-it.log"
done

echo "All simulation tasks have been submitted."

