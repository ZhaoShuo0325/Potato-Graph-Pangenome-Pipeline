#!/bin/bash

HOME="/public/home/zhaoshuo/work1"
WORK_DIR="$HOME/01_work/00_pggb"
FA="$WORK_DIR/group60.chr01.fa.gz"
OUT_DIR="$WORK_DIR/00_pggb_output"

pggb -i $FA -o $OUT_DIR -t 128 -p 90 -s 10000 -n 61 -G 700,900,1100 -k 47 -O 0.001 -P asm20 -v
