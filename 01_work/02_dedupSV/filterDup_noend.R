#!/usr/bin/env Rscript
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 3) stop("Usage: Rscript DupFilter.R <in_dir> <chr> <out_dir>")

input_dir <- args[1]; current_chr <- args[2]; output_dir <- args[3]
if(!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

library(VariantAnnotation)
library(GenomicRanges)
library(dplyr)
library(igraph)

# 1. 加载数据
vcf_file <- file.path(input_dir, paste0(current_chr, "_merged.vcf.gz"))
svs <- readVcf(vcf_file)
# 确保 ID 唯一且稳健，防止 merge 报错
names(svs) <- paste0('sv', 1:length(svs))

# 2. 建立 GRanges 对象并处理坐标
svs.gr <- rowRanges(svs)
# 修复 SIZE：将 SVLEN 转为正整数绝对值
svs.gr$size <- abs(as.integer(unlist(info(svs)$SVLEN)))
svs.gr$type <- as.character(unlist(info(svs)$SVTYPE))

# --- 智能处理 END 信息：有则保持，无则补全 ---
# 提取 VCF 中 INFO 栏的 END 标签
vcf_info_end <- as.integer(unlist(info(svs)$END))
missing_end <- is.na(vcf_info_end)

# A. 如果 VCF 里有 END 信息，原样保留，绝不修改
if(any(!missing_end)) {
    end(svs.gr)[!missing_end] <- vcf_info_end[!missing_end]
}

# B. 如果缺失 END 信息，针对 DEL 类型根据 SVLEN 自动补全
if(any(missing_end)) {
    is_del <- svs.gr$type == 'DEL'
    to_fix <- missing_end & is_del
    if(any(to_fix)) {
        # 补全逻辑：End = Start + Size - 1
        end(svs.gr)[to_fix] <- start(svs.gr)[to_fix] + svs.gr$size[to_fix] - 1
    }
}

# C. 安全冗余：确保 end 坐标不早于 start
bad_coords <- end(svs.gr) < start(svs.gr)
if(any(bad_coords)) end(svs.gr)[bad_coords] <- start(svs.gr)[bad_coords]
# ----------------------------------------------

# 3. 重叠参数
min.rol <- 0.8
max.ins.gap <- 50

# 4. 计算 INS 重叠 (基于原始逻辑)
ol.ins <- data.frame()
ins.gr <- svs.gr[which(svs.gr$type=='INS')]
if(length(ins.gr) > 1){
  ol.ins <- findOverlaps(ins.gr, ins.gr, maxgap=max.ins.gap) %>%
    as.data.frame() %>% filter(queryHits < subjectHits) %>% 
    mutate(qs=ins.gr$size[queryHits], ss=ins.gr$size[subjectHits],
           qid=names(ins.gr)[queryHits], sid=names(ins.gr)[subjectHits],
           rol=ifelse(qs > ss, ss/qs, qs/ss)) %>%
    select(-queryHits, -subjectHits) %>% 
    filter(rol > min.rol)
}

# 5. 计算 DEL 重叠 (基于原始逻辑)
ol.del <- data.frame()
del.gr <- svs.gr[which(svs.gr$type=='DEL')]
if(length(del.gr) > 1){
  ol.del <- findOverlaps(del.gr, del.gr) %>%
    as.data.frame() %>% filter(queryHits < subjectHits) %>% 
    mutate(qs=del.gr$size[queryHits], ss=del.gr$size[subjectHits],
           qss=width(pintersect(del.gr[queryHits], del.gr[subjectHits])),
           qid=names(del.gr)[queryHits], sid=names(del.gr)[subjectHits],
           rol=ifelse(qs > ss, qss/qs, qss/ss)) %>%
    select(-queryHits, -subjectHits, -qss) %>% 
    filter(rol > min.rol)
}

# 6. 整合并识别冗余
ol.df <- rbind(ol.ins, ol.del)
ids_to_remove <- character(0)

if(nrow(ol.df) > 0){
  # 建立图论聚类
  ol.g <- ol.df %>% select(qid, sid) %>% as.matrix %>% graph_from_edgelist(directed=FALSE)
  ol.c <- components(ol.g)
  ol.c.df <- tibble(id = names(ol.c$membership), cmp = as.numeric(ol.c$membership))
  
  # A. 生成聚类 TSV 报告
  svs.df <- tibble(seqnames = as.character(seqnames(svs)), start = start(svs), end = end(svs), id = names(svs))
  cl.df <- merge(svs.df, ol.c.df) %>% group_by(cmp, seqnames) %>%
    summarize(start = min(start) - 1000, end = max(end) + 1000, ids = paste(id, collapse = ','), .groups = 'drop')
  write.table(cl.df, file = file.path(output_dir, paste0('neardups-clusters-', current_chr, '.tsv')), 
              quote = FALSE, sep = '\t', row.names = FALSE)
  
  # B. 核心去重：找出聚类中除首个 ID 以外的所有冗余 ID
  ids_to_remove <- ol.c.df %>% group_by(cmp) %>% slice(-1) %>% pull(id)
}

# 7. 最终输出：剔除冗余，保留唯一变异和聚类代表
svs_filtered <- svs[!(names(svs) %in% ids_to_remove), ]
writeVcf(svs_filtered, file.path(output_dir, paste0('filterDup_', current_chr, '.vcf')))

cat(paste0(current_chr, " Done. Original: ", length(svs), " | Removed: ", length(ids_to_remove), " | Remaining: ", length(svs_filtered), "\n"))