#!/bin/bash
#SBATCH --partition=AMD_9A14
#SBATCH --mem=256G
#SBATCH --cpus-per-task=128
#SBATCH --job-name=evaluate_type_bayestyper
#SBATCH --output=%x.out
#SBATCH --error=%x.err

# source ~/.bashrc
# conda activate truvari_env

d=5
HOME="/public/home/zhaoshuo/work1"
TRUTH_VCF_DIR="$HOME/data/simulated/truth_vcf"
QUERY_VCF="$HOME/gt/bayestyper/exp1/Sim_01_02_d${d}/result/Sim_01_02_final_genotype.vcf.gz"
OUT_DIR="$HOME/gt/bayestyper/exp1/Sim_01_02_d${d}/evaluate_type_sv"
GENOME_DIR="$HOME/data/simulated/genomes"
REF_FA="$HOME/data/reference/DM8.1_genome.fasta.gz" # 参考序列
PYTHON_SCRIPT="/public/home/zhaoshuo/work1/graph/pggb/scripts/fix_pggb_vcf.py"
REF_PREFIX="DM8"

rm -rf $OUT_DIR
mkdir -p $OUT_DIR

fix_pggb_vcf() {
    local input=$1
    local output=$2
    local ref_prefix=$3
    
    # 获取 Python 脚本的绝对路径，确保在不同目录下都能找到
    local python_script="$PYTHON_SCRIPT"

    echo "[$(date +'%H:%M:%S')] 正在修复 VCF: $input -> $output"

    # 管道调用：sed -> bcftools -> 你的外部python脚本 -> bcftools sort
    sed "s/${ref_prefix}#0#//g" "$input" | \
    bcftools norm -m -any --force | \
    python3 "$python_script" | \
    bcftools sort -Oz -o "$output"

    tabix -f -p vcf "$output"
    echo "[$(date +'%H:%M:%S')] 修复完成: $output"
}

# 规范化真集 VCF
fix_truth_vcf() {
    local input=$1
    local output=$2

    bcftools view "$input" | \
    bcftools filter -i 'SVLEN >= 50 || SVLEN <= -50' | \
    bcftools sort -Oz -o "$output"

    tabix -f -p vcf "$output"
}

# 准备真集 VCF
for sample in Sim_01 Sim_02; do
    fix_truth_vcf "$TRUTH_VCF_DIR/${sample}_fixed.vcf" "$OUT_DIR/${sample}_truth_all.vcf.gz"
done

echo "[$(date +'%Y-%m-%d %H:%M:%S')] ----- Fixing VCF & Classifying SVs -----"
fix_pggb_vcf "$QUERY_VCF" "$OUT_DIR/final.vcf.gz" "$REF_PREFIX"

# --- 分样本、分类型评估运行 Truvari ---
echo "[$(date +'%H:%M:%S')] ----- Running Truvari -----"
SUMMARY_CSV="$OUT_DIR/sv_evaluation_detailed.csv"
# 预设表头
echo "Sample,Type,Recall,Precision,F1,GT_Conc,TP,FP,FN" > "$SUMMARY_CSV"

for sample in Sim_01 Sim_02; do
    echo "[$(date +'%H:%M:%S')] >>> Processing Sample: $sample"

    # 1. 从解构的 Query VCF 中提取当前样本
    SAMPLE_QUERY_ALL="$OUT_DIR/${sample}_query_all.vcf.gz"
    bcftools view -s "$sample" -c 1 "$OUT_DIR/final.vcf.gz" -Oz -o "$SAMPLE_QUERY_ALL"
    tabix -f -p vcf "$SAMPLE_QUERY_ALL"

    # 2. 循环评估类型
    for type in TOTAL INS DEL INV; do
        sub_truth="$OUT_DIR/${sample}_truth_${type}.vcf.gz"
        sub_query="$OUT_DIR/${sample}_query_${type}.vcf.gz"
        tru_out_dir="$OUT_DIR/truvari_${sample}_${type}"
        rm -rf "$tru_out_dir"

        # 提取特定类型的变异
        if [ "$type" == "TOTAL" ]; then
            cp "$OUT_DIR/${sample}_truth_all.vcf.gz" "$sub_truth"
            cp "$SAMPLE_QUERY_ALL" "$sub_query"
        else
            # 使用 -i 过滤 SVTYPE
            bcftools view -i "INFO/SVTYPE='$type'" "$OUT_DIR/${sample}_truth_all.vcf.gz" -Oz -o "$sub_truth"
            bcftools view -i "INFO/SVTYPE='$type'" "$SAMPLE_QUERY_ALL" -Oz -o "$sub_query"
        fi
        tabix -f -p vcf "$sub_truth" && tabix -f -p vcf "$sub_query"

        # 3. 运行 Truvari
        truvari bench -b "$sub_truth" -c "$sub_query" -f "$REF_FA" -o "$tru_out_dir" \
            --sizemin 50 --sizemax 1000000 --pctseq 0.0 --pctsize 0.75 --refdist 200 --no-ref a

        # 4. 解析结果
        if [ -f "$tru_out_dir/summary.json" ]; then
            get_val() { 
                grep "\"$1\":" "$tru_out_dir/summary.json" | head -n1 | awk -F': ' '{print $2}' | sed 's/[,[:space:]]//g'
            }
            REC=$(get_val "recall")
            PRE=$(get_val "precision")
            F1=$(get_val "f1")
            GTC=$(get_val "gt_concordance")
            TP=$(get_val "TP-base")
            FP=$(get_val "FP")
            FN=$(get_val "FN")
            echo "$sample,$type,$REC,$PRE,$F1,$GTC,$TP,$FP,$FN" >> "$SUMMARY_CSV"
        else
            echo "$sample,$type,0,0,0,0,0,0,0" >> "$SUMMARY_CSV"
        fi
    done
done

# --- 打印报告 ---
echo -e "\n"
echo "================================= SV EVALUATION REPORT ================================="
awk -F',' 'BEGIN {printf "%-10s | %-6s | %-8s | %-8s | %-8s | %-8s | %-5s | %-5s | %-5s\n", "Sample", "Type", "Recall", "Precis.", "F1", "GT_Conc", "TP", "FP", "FN"; print "---------------------------------------------------------------------------------------"} 
NR>1 {printf "%-10s | %-6s | %-8.4f | %-8.4f | %-8.4f | %-8.4f | %-5d | %-5d | %-5d\n", $1, $2, $3, $4, $5, $6, $7, $8, $9}' "$SUMMARY_CSV"
echo "======================================================================================="
