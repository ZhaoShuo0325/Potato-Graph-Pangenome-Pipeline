#!/usr/bin/env Rscript
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 3) stop("Usage: Rscript DupFilter.R <in_dir> <chr> <out_dir>")

input_dir <- args[1]; current_chr <- args[2]; output_dir <- args[3]
if(!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

library(VariantAnnotation)
library(GenomicRanges)
library(dplyr)
library(igraph)

vcf_file <- file.path(input_dir, paste0(current_chr, "_merged.vcf.gz"))
svs <- readVcf(vcf_file)
names(svs) <- paste0('sv', 1:length(svs))

svs.gr <- rowRanges(svs)
svs.gr$size <- abs(as.integer(unlist(info(svs)$SVLEN)))
svs.gr$type <- as.character(unlist(info(svs)$SVTYPE))

# 提取 VCF 中 INFO 栏的 END 标签
vcf_info_end <- as.integer(unlist(info(svs)$END))
missing_end <- is.na(vcf_info_end)

if(any(!missing_end)) {
    end(svs.gr)[!missing_end] <- vcf_info_end[!missing_end]
}

if(any(missing_end)) {
    is_del <- svs.gr$type == 'DEL'
    to_fix <- missing_end & is_del
    if(any(to_fix)) {
        # End = Start + Size - 1
        end(svs.gr)[to_fix] <- start(svs.gr)[to_fix] + svs.gr$size[to_fix] - 1
    }
}

bad_coords <- end(svs.gr) < start(svs.gr)
if(any(bad_coords)) end(svs.gr)[bad_coords] <- start(svs.gr)[bad_coords]

# 过滤条件
min.rol <- 0.8
max.ins.gap <- 50

# 计算 INS 重叠
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

# 计算 DEL 重叠
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

ol.df <- rbind(ol.ins, ol.del)
ids_to_remove <- character(0)

if(nrow(ol.df) > 0){
  ol.g <- ol.df %>% select(qid, sid) %>% as.matrix %>% graph_from_edgelist(directed=FALSE)
  ol.c <- components(ol.g)
  ol.c.df <- tibble(id = names(ol.c$membership), cmp = as.numeric(ol.c$membership))
  
  svs.df <- tibble(seqnames = as.character(seqnames(svs)), start = start(svs), end = end(svs), id = names(svs))
  cl.df <- merge(svs.df, ol.c.df) %>% group_by(cmp, seqnames) %>%
    summarize(start = min(start) - 1000, end = max(end) + 1000, ids = paste(id, collapse = ','), .groups = 'drop')
  write.table(cl.df, file = file.path(output_dir, paste0('neardups-clusters-', current_chr, '.tsv')), 
              quote = FALSE, sep = '\t', row.names = FALSE)
  
  # 过滤聚类中除首个 ID 以外的所有冗余 ID
  ids_to_remove <- ol.c.df %>% group_by(cmp) %>% slice(-1) %>% pull(id)
}

svs_filtered <- svs[!(names(svs) %in% ids_to_remove), ]
writeVcf(svs_filtered, file.path(output_dir, paste0('DupFilter_', current_chr, '.vcf')))

cat(paste0(current_chr, " Done. Original: ", length(svs), " | Removed: ", length(ids_to_remove), " | Remaining: ", length(svs_filtered), "\n"))
