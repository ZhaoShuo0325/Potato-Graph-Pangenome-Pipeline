#!/bin/bash
#SBATCH --partition=AMD_9A14
#SBATCH --mem=256G
#SBATCH --cpus-per-task=128
#SBATCH --job-name=evaluate_type_pggb
#SBATCH --output=%x.out
#SBATCH --error=%x.err

# source ~/.bashrc
# conda activate simit_env

HOME="/public/home/zhaoshuo/work1"
TRUTH_VCF_DIR="$HOME/data/simulated/truth_vcf"
RAW_QUERY_VCF="$HOME/graph/pggb/exp1/Sim_01_02_total_p99_s10000_k47_n5/deconstruct/pggb_gfa_sv_raw.vcf"
OUT_DIR="$HOME/graph/pggb/exp1/Sim_01_02_total_p99_s10000_k47_n5/deconstruct/evaluate_type_sv"
GENOME_DIR="$HOME/data/simulated/genomes"
REF_FA="$HOME/data/reference/DM8.1_genome.fasta.gz" # 参考序列
REF_PREFIX="DM8"

# source ~/.bashrc
# conda activate truvari_env

rm -rf $OUT_DIR
mkdir -p $OUT_DIR

# 修复解构的 VCF
fix_pggb_vcf() {
    local input=$1
    local output=$2
    local ref_prefix=$3  # 例如 "DM8"

    echo "[$(date +'%H:%M:%S')] 正在修复 VCF: $input -> $output"

    # 移除前缀并拆分多等位基因
    # sed 移除类似 "DM8#0#" 的前缀
    # bcftools norm -m -any 会把 A -> T,C 拆成两行，确保 awk 计算长度不报错
    sed "s/${ref_prefix}#0#//g" "$input" | \
    bcftools norm -m -any --force | \
    awk 'BEGIN {OFS="\t"} 
        /^##/ { if ($0 ~ /ID=SVLEN/ || $0 ~ /ID=SVTYPE/) next; print $0; next } 
        /^#CHROM/ {
            print "##INFO=<ID=SVLEN,Number=1,Type=Integer,Description=\"Difference in length\">"; 
            print "##INFO=<ID=SVTYPE,Number=1,Type=String,Description=\"Type of SV\">"; 
            print $0; next
        } 
        {
            ref_l = length($4); alt_l = length($5); diff = alt_l - ref_l;
            if (diff > 0) { type="INS"; len=diff; }
            else if (diff < 0) { type="DEL"; len=-diff; }
            else { next; }

            if (len >= 50) {
                tag = "SVTYPE=" type ";SVLEN=" len;
                $8 = ($8 == "." || $8 == "") ? tag : tag ";" $8;
                print $0;
            }
        }' | bcftools sort -Oz -o "$output"
    tabix -f -p vcf "$output"
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
echo "[$(date +'%H:%M:%S')] ----- Prepare fixed truth VCF -----"
for sample in Sim_01 Sim_02; do
    fix_truth_vcf "$TRUTH_VCF_DIR/${sample}_fixed.vcf" "$OUT_DIR/${sample}_truth_all.vcf.gz"
done
# 准备Query VCF
echo "[$(date +'%H:%M:%S')] ----- Prepare fixed query VCF -----"
FIXED_FULL_QUERY="$OUT_DIR/pggb_query_full_fixed.vcf.gz"
fix_pggb_vcf "$RAW_QUERY_VCF" "$FIXED_FULL_QUERY" "$REF_PREFIX"

# 分样本评估运行 Truvari
echo "[$(date +'%H:%M:%S')] ----- Running Truvari -----"
SUMMARY_CSV="$OUT_DIR/sv_evaluation_detailed.csv"
# 预设表头
echo "Sample,Type,Recall,Precision,F1,GT_Conc,TP,FP,FN" > "$SUMMARY_CSV"

for sample in Sim_01 Sim_02; do
    echo "[$(date +'%H:%M:%S')] >>> Processing Sample: $sample"
    
    SAMPLE_QUERY_ALL="$OUT_DIR/${sample}_query_all.vcf.gz"
    bcftools view -s "$sample" -c 1 "$FIXED_FULL_QUERY" -Oz -o "$SAMPLE_QUERY_ALL" && tabix -f -p vcf "$SAMPLE_QUERY_ALL"

    for type in TOTAL INS DEL; do
        sub_truth="$OUT_DIR/${sample}_truth_${type}.vcf.gz"
        sub_query="$OUT_DIR/${sample}_query_${type}.vcf.gz"
        tru_out_dir="$OUT_DIR/truvari_${sample}_${type}"
        rm -rf "$tru_out_dir"

        if [ "$type" == "TOTAL" ]; then
            cp "$OUT_DIR/${sample}_truth_all.vcf.gz" "$sub_truth"
            cp "$SAMPLE_QUERY_ALL" "$sub_query"
        else
            bcftools view -i "INFO/SVTYPE='$type'" "$OUT_DIR/${sample}_truth_all.vcf.gz" -Oz -o "$sub_truth"
            bcftools view -i "INFO/SVTYPE='$type'" "$SAMPLE_QUERY_ALL" -Oz -o "$sub_query"
        fi
        tabix -f -p vcf "$sub_truth" && tabix -f -p vcf "$sub_query"

        # 运行 Truvari
        truvari bench -b "$sub_truth" -c "$sub_query" -f "$REF_FA" -o "$tru_out_dir" \
            --sizemin 50 --sizemax 1000000 --pctseq 0.0 --pctsize 0.5 --refdist 1000 --no-ref a

        # 解析 JSON 结果并确保格式纯净
        if [ -f "$tru_out_dir/summary.json" ]; then
            # 辅助函数：提取并清理 JSON 数值
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

            # 写入 CSV
            echo "$sample,$type,$REC,$PRE,$F1,$GTC,$TP,$FP,$FN" >> "$SUMMARY_CSV"
        else
            echo "$sample,$type,0,0,0,0,0,0,0" >> "$SUMMARY_CSV"
        fi
    done
done

# --- 最终可视化打印 ---
echo -e "\n"
echo "================================= SV EVALUATION REPORT ================================="
# 使用 printf 进行完美对齐打印
awk -F',' 'BEGIN {printf "%-10s | %-6s | %-8s | %-8s | %-8s | %-8s | %-5s | %-5s | %-5s\n", "Sample", "Type", "Recall", "Precis.", "F1", "GT_Conc", "TP", "FP", "FN"; print "---------------------------------------------------------------------------------------"} 
NR>1 {printf "%-10s | %-6s | %-8.4f | %-8.4f | %-8.4f | %-8.4f | %-5d | %-5d | %-5d\n", $1, $2, $3, $4, $5, $6, $7, $8, $9}' "$SUMMARY_CSV"
echo "======================================================================================="
echo -e "Detailed results saved to: $SUMMARY_CSV\n"
