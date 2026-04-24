#!/bin/bash
#SBATCH --partition=AMD_9A14
#SBATCH --mem=256G
#SBATCH --cpus-per-task=128
#SBATCH --job-name=evaluate_type_varigraph
#SBATCH --output=%x.out
#SBATCH --error=%x.err

# source ~/.bashrc
# conda activate truvari_env

d=5
HOME="/public/home/zhaoshuo/work1"
TRUTH_VCF_DIR="$HOME/data/simulated/truth_vcf"
QUERY_VCF_DIR="$HOME/gt/varigraph/exp1/Sim_01_02_vari_d${d}"
OUT_DIR="$HOME/gt/varigraph/exp1/Sim_01_02_vari_d${d}/evaluate"
REF_FA="$HOME/data/reference/DM8.1_genome.fasta.gz" # 参考序列
REF_PREFIX="DM8"

rm -rf $OUT_DIR
mkdir -p $OUT_DIR

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

# 分样本评估运行 Truvari
echo "[$(date +'%H:%M:%S')] ----- Running Truvari -----"
SUMMARY_CSV="$OUT_DIR/sv_evaluation_detailed.csv"
# 预设表头
echo "Sample,Type,Recall,Precision,F1,GT_Conc,TP,FP,FN" > "$SUMMARY_CSV"

for sample in Sim_01 Sim_02; do
    echo "[$(date +'%H:%M:%S')] >>> Processing Sample: $sample"
    SAMPLE_FIXED_QUERY="$QUERY_VCF_DIR/${sample}.varigraph.vcf.gz"
    SAMPLE_FIXED_TRUTH="$OUT_DIR/${sample}_truth_all.vcf.gz"

    for type in TOTAL INS DEL INV; do
        sub_truth="$OUT_DIR/${sample}_truth_${type}.vcf.gz"
        sub_query="$OUT_DIR/${sample}_query_${type}.vcf.gz"
        tru_out_dir="$OUT_DIR/truvari_${sample}_${type}"
        rm -rf "$tru_out_dir"

        if [ "$type" == "TOTAL" ]; then
            bcftools norm -m -any "$SAMPLE_FIXED_TRUTH" -Oz -o "$sub_truth"
            bcftools norm -m -any "$SAMPLE_FIXED_QUERY" -Oz -o "$sub_query"
        else
            # 按类型过滤
            bcftools view -i "INFO/SVTYPE='$type'" "$SAMPLE_FIXED_TRUTH" -Ou | \
            bcftools norm -m -any -Oz -o "$sub_truth"
        
            bcftools view -i "INFO/SVTYPE='$type'" "$SAMPLE_FIXED_QUERY" -Ou | \
            bcftools norm -m -any -Oz -o "$sub_query"
        fi
        tabix -f -p vcf "$sub_truth" && tabix -f -p vcf "$sub_query"

        # 运行 Truvari
        truvari bench -b "$sub_truth" -c "$sub_query" -f "$REF_FA" -o "$tru_out_dir" \
            --sizemin 50 --pctseq 0.0 --pctsize 0.75 --refdist 200

        # 解析 JSON 结果
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

# --- 最终可视化打印 (保持不变) ---
# --- 最终可视化打印 (保持不变) ---
echo -e "\n"
echo "================================= SV EVALUATION REPORT ================================="
awk -F',' 'BEGIN {printf "%-10s | %-6s | %-8s | %-8s | %-8s | %-8s | %-5s | %-5s | %-5s\n", "Sample", "Type", "Recall", "Precis.", "F1", "GT_Conc", "TP", "FP", "FN"; print "---------------------------------------------------------------------------------------"} 
NR>1 {printf "%-10s | %-6s | %-8.4f | %-8.4f | %-8.4f | %-8.4f | %-5d | %-5d | %-5d\n", $1, $2, $3, $4, $5, $6, $7, $8, $9}' "$SUMMARY_CSV"
echo "======================================================================================="