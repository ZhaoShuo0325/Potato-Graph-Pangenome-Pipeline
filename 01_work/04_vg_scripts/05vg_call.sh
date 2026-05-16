#!/bin/bash
d=5 #测序深度
HOME="/public/home/zhaoshuo/work1"
REF="$HOME/data/reference/DM8.1_genome.ori.chr.fa"
GAM_DIR="$HOME/merge_test/02_graph/04_vg_merge/giraffe/giraffe_d${d}"
XG_DIR="$HOME/merge_test/02_graph/04_vg_merge/prep"
CHR="$HOME/merge_test/00_data/chrs.txt"
PACK_DIR="$HOME/merge_test/02_graph/04_vg_merge/giraffe/giraffe_d${d}/vg_call"
SNARLS_DIR="$HOME/merge_test/02_graph/04_vg_merge/prep"
OUT_DIR="$HOME/merge_test/02_graph/04_vg_merge/giraffe/giraffe_d${d}/vg_call/results"

for chr in $(cat $CHR); do
mkdir -p "$OUT_DIR"
XG="$XG_DIR/vg_merge_${chr}.xg"
SNARLS="$SNARLS_DIR/vg_merge_${chr}.snarls"
LIST="$HOME/merge_test/00_data/real.txt"
REF_PATHS=\$(vg paths -L -x "\$XG" | grep -v "_alt_" | sed 's/^/-p /' | tr '\n' ' ')
for SAMPLE in \$(cat \$LIST); do
    vg call -t 128 "\$XG" \
        -r \$SNARLS \
        -k "$PACK_DIR/\${SAMPLE}_${chr}.pack" \
        -s "\$SAMPLE" \
        \$REF_PATHS > "$OUT_DIR/\${SAMPLE}_${chr}.raw.vcf"
done
done
