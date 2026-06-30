#!/bin/bash
#mamba install -c conda-forge r-tidyverse r-svglite --override-channels
Rscript="/public/home/zhaoshuo/miniconda3/envs/R_env/bin/Rscript"
GRAPH="/public/home/zhaoshuo/work1/merge_test/04_compare/01_sim_giraffe/roc_stats_giraffe.ft.tsv"
BWA="/public/home/zhaoshuo/work1/merge_test/04_compare/03bwa_linear/roc_stats_bwa_bwa_linear.ft.tsv"
GIRAFFE="/public/home/zhaoshuo/work1/merge_test/04_compare/02sim_linear/roc_stats_graph-linear.ft.tsv"
OUT_DIR="/public/home/zhaoshuo/work1/merge_test/04_compare/04roc_plot"
mkdir -p $OUT_DIR

head -n 1 $GRAPH > $OUT_DIR/all_roc_stats.ft.tsv
tail -n +2 $GRAPH >> $OUT_DIR/all_roc_stats.ft.tsv
tail -n +2 $GIRAFFE >> $OUT_DIR/all_roc_stats.ft.tsv
tail -n +2 $BWA >> $OUT_DIR/all_roc_stats.ft.tsv

$Rscript plot-roc.R $OUT_DIR/all_roc_stats.ft.tsv $OUT_DIR/all_roc.ft.roc.pdf
