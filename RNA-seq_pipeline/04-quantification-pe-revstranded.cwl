#!/usr/bin/env cwl-runner
cwlVersion: "cwl:draft-3"
class: Workflow
description: "RNA-seq 04 quantification"
requirements:
  - class: ScatterFeatureRequirement
  - class: StepInputExpressionRequirement
  - class: InlineJavascriptRequirement
  - class: SubworkflowFeatureRequirement
inputs:
  - id: "#input_bam_files"
    type: {type: array, items: File}
  - id: "#input_transcripts_bam_files"
    type: {type: array, items: File}
  - id: "#rsem_reference_files"
    type: {type: array, items: File}
    description: "RSEM genome reference files - generated with the rsem-prepare-reference command"
  - id: "#input_genome_sizes"
    type: File
  - id: "#annotation_file"
    type: File
    description: "GTF annotation file"
  - id: "#bamtools_forward_filter_file"
    type: File
    description: "JSON filter file for forward strand used in bamtools (see bamtools-filter command)"
  - id: "#bamtools_reverse_filter_file"
    type: File
    description: "JSON filter file for reverse strand used in bamtools (see bamtools-filter command)"
  - id: "#nthreads"
    type: int
    default: 1
outputs:
  - id: "#featurecounts_counts"
    source: "#featurecounts.output_files"
    description: "Normalized fragment extended reads bigWig (signal) files"
    type: {type: array, items: File}
  - id: "#rsem_isoforms_files"
    source: "#rsem-calc-expr.isoforms"
    description: "RSEM isoforms files"
    type: {type: array, items: File}
  - id: "#rsem_genes_files"
    source: "#rsem-calc-expr.genes"
    description: "RSEM genes files"
    type: {type: array, items: File}
  - id: "#bam_plus_files"
    source: "#split_bams.bam_plus_files"
    description: "BAM files containing only reads in the forward (plus) strand."
    type: {type: array, items: File}
  - id: "#bam_minus_files"
    source: "#split_bams.bam_minus_files"
    description: "BAM files containing only reads in the reverse (minus) strand."
    type: {type: array, items: File}
  - id: "#index_bam_plus_files"
    source: "#split_bams.index_bam_plus_files"
    description: "Index files for BAM files containing only reads in the forward (plus) strand."
    type: {type: array, items: File}
  - id: "#index_bam_minus_files"
    source: "#split_bams.index_bam_minus_files"
    description: "Index files for BAM files containing only reads in the reverse (minus) strand."
    type: {type: array, items: File}
  - id: "#bw_raw_plus_files"
    source: "#bdg2bw-raw-plus.output_bigwig"
    description: "Raw bigWig files from BAM files containing only reads in the forward (plus) strand."
    type: {type: array, items: File}
  - id: "#bw_raw_minus_files"
    source: "#bdg2bw-raw-minus.output_bigwig"
    description: "Raw bigWig files from BAM files containing only reads in the reverse (minus) strand."
    type: {type: array, items: File}
  - id: "#bw_norm_plus_files"
    source: "#bamcoverage-plus.output_bam_coverage"
    description: "Normalized by RPKM bigWig files from BAM files containing only reads in the forward (plus) strand."
    type: {type: array, items: File}
  - id: "#bw_norm_minus_files"
    source: "#bdg2bw-norm-minus.output_bigwig"
    description: "Normalized by RPKM bigWig files from BAM files containing only reads in the forward (plus) strand."
    type: {type: array, items: File}
steps:
  - id: "#basename"
    run: {$import: "../utils/basename.cwl" }
    scatter: "#basename.file_path"
    inputs:
      - id: "#basename.file_path"
        source: "#input_bam_files"
        valueFrom: $(self.path)
      - id: "#sep"
        valueFrom: '\.Aligned\.out\.sorted'
    outputs:
      - id: "#basename.basename"
  - id: "#featurecounts"
    run: {$import: "../quant/subread-featurecounts.cwl"}
    scatter:
      - "#featurecounts.input_files"
      - "#featurecounts.output_filename"
    scatterMethod: dotproduct
    inputs:
      - id: "#featurecounts.input_files"
        source: "#input_bam_files"
        valueFrom: ${if (Array.isArray(self)) return self; return [self]; }
      - id: "#featurecounts.output_filename"
        source: "#basename.basename"
        valueFrom: $(self + ".featurecounts.counts.txt")
      - { id: "#featurecounts.annotation_file", source: "#annotation_file" }
      - { id: "#featurecounts.p", valueFrom: $(true) }
      - { id: "#featurecounts.B", valueFrom: $(true) }
      - { id: "#featurecounts.t", valueFrom: "exon" }
      - { id: "#featurecounts.g", valueFrom: "gene_id" }
      - { id: "#featurecounts.s", valueFrom: $(2) }
      - { id: "#featurecounts.T", source: "#nthreads" }
    outputs:
      - id: "#featurecounts.output_files"
  - id: "#rsem-calc-expr"
    run: {$import: "../quant/rsem-calculate-expression.cwl"}
    scatter:
      - "#rsem-calc-expr.bam"
      - "#rsem-calc-expr.sample_name"
    scatterMethod: dotproduct
    inputs:
      - { id: "#rsem-calc-expr.bam", source: "#input_transcripts_bam_files"}
      - { id: "#rsem-calc-expr.reference_files", source: "#rsem_reference_files"}
      - id: "#rsem-calc-expr.sample_name"
        source: "#basename.basename"
        valueFrom: $(self + ".rsem")
      - id: "#rsem-calc-expr.reference_name"
        source: "#rsem_reference_files"
        valueFrom: |
          ${
            var trans_file_str = self.map(function(e){return e.path}).filter(function(e){return e.match(/\.transcripts\.fa$/)})[0];
            return trans_file_str.match(/.*[\\\/](.*)\.transcripts\.fa$/)[1];
          }
      - { id: "#rsem-calc-expr.paired-end", valueFrom: $(true) }
      - { id: "#rsem-calc-expr.no-bam-output", valueFrom: $(true) }
      - { id: "#rsem-calc-expr.seed", valueFrom: $(1234) }
      - { id: "#rsem-calc-expr.num-threads", source: "#nthreads" }
      - { id: "#rsem-calc-expr.quiet", valueFrom: $(true) }
    outputs:
      - id: "#rsem-calc-expr.isoforms"
      - id: "#rsem-calc-expr.genes"
      - id: "#rsem-calc-expr.rsem_stat"
  - id: "#split_bams"
    run: {$import: "../quant/split-bams-by-strand-and-index.cwl"}
    inputs:
      - {id: "#split_bams.input_bam_files", source: "#input_bam_files"}
      - {id: "#split_bams.input_basenames", source: "#basename.basename"}
      - {id: "#split_bams.bamtools_forward_filter_file", source: "#bamtools_forward_filter_file"}
      - {id: "#split_bams.bamtools_reverse_filter_file", source: "#bamtools_reverse_filter_file"}
    outputs:
      - {id: "#split_bams.bam_plus_files"}
      - {id: "#split_bams.bam_minus_files"}
      - {id: "#split_bams.index_bam_plus_files"}
      - {id: "#split_bams.index_bam_minus_files"}
  - id: "#bedtools_genomecov_plus"
    run: {$import: "../map/bedtools-genomecov.cwl"}
    scatter: "#bedtools_genomecov_plus.ibam"
    inputs:
      - { id: "#bedtools_genomecov_plus.ibam",  source: "#split_bams.bam_plus_files" }
      - { id: "#bedtools_genomecov_plus.g", source: "#input_genome_sizes"}
      - { id: "#bedtools_genomecov_plus.bg", valueFrom: $(true) }
    outputs:
      - id: "#bedtools_genomecov_plus.output_bedfile"
  - id: "#bedtools_genomecov_minus"
    run: {$import: "../map/bedtools-genomecov.cwl"}
    scatter: "#bedtools_genomecov_minus.ibam"
    inputs:
      - { id: "#bedtools_genomecov_minus.ibam", source: "#split_bams.bam_minus_files" }
      - { id: "#bedtools_genomecov_minus.g", source: "#input_genome_sizes"}
      - { id: "#bedtools_genomecov_minus.bg", valueFrom: $(true) }
    outputs:
      - id: "#bedtools_genomecov_minus.output_bedfile"
  - id: "#bedsort_genomecov_plus"
    run: {$import: "../quant/bedSort.cwl"}
    scatter: "#bedsort_genomecov_plus.bed_file"
    inputs:
      - { id: "#bedsort_genomecov_plus.bed_file",  source: "#bedtools_genomecov_plus.output_bedfile" }
    outputs:
      - id: "#bedsort_genomecov_plus.bed_file_sorted"
  - id: "#bedsort_genomecov_minus"
    run: {$import: "../quant/bedSort.cwl"}
    scatter: "#bedsort_genomecov_minus.bed_file"
    inputs:
      - { id: "#bedsort_genomecov_minus.bed_file",  source: "#bedtools_genomecov_minus.output_bedfile" }
    outputs:
      - id: "#bedsort_genomecov_minus.bed_file_sorted"
  - id: "#negate_minus_bdg"
    run: {$import: "../quant/negate-minus-strand-bedgraph.cwl"}
    scatter:
      - "#negate_minus_bdg.bedgraph_file"
      - "#negate_minus_bdg.output_filename"
    scatterMethod: dotproduct
    inputs:
      - { id: "#negate_minus_bdg.bedgraph_file",  source: "#bedsort_genomecov_minus.bed_file_sorted" }
      - id: "#negate_minus_bdg.output_filename"
        source: "#basename.basename"
        valueFrom: $(self + ".Aligned.minus.raw.bdg")
    outputs:
      - id: "#negate_minus_bdg.negated_minus_bdg"
  - id: "#bdg2bw-raw-plus"
    run: {$import: "../quant/bedGraphToBigWig.cwl"}
    scatter: "#bdg2bw-raw-plus.bed_graph"
    inputs:
      - { id: "#bdg2bw-raw-plus.bed_graph", source: "#bedsort_genomecov_plus.bed_file_sorted" }
      - { id: "#bdg2bw-raw-plus.genome_sizes", source: "#input_genome_sizes" }
      - { id: "#bdg2bw-raw-plus.output_suffix", valueFrom: ".raw.bw" }
    outputs:
      - id: "#bdg2bw-raw-plus.output_bigwig"
  - id: "#bdg2bw-raw-minus"
    run: {$import: "../quant/bedGraphToBigWig.cwl"}
    scatter: "#bdg2bw-raw-minus.bed_graph"
    inputs:
      - { id: "#bdg2bw-raw-minus.bed_graph", source: "#negate_minus_bdg.negated_minus_bdg" }
      - { id: "#bdg2bw-raw-minus.genome_sizes", source: "#input_genome_sizes" }
      - { id: "#bdg2bw-raw-minus.output_suffix", valueFrom: ".bw" }
    outputs:
      - id: "#bdg2bw-raw-minus.output_bigwig"
  - id: "#bamcoverage-plus"
    run: {$import: "../quant/deeptools-bamcoverage.cwl"}
    scatter: "#bamcoverage-plus.bam"
    inputs:
      - { id: "#bamcoverage-plus.bam", source: "#split_bams.bam_plus_files" }
      - { id: "#bamcoverage-plus.output_suffix", valueFrom: ".norm.bw" }
      - { id: "#bamcoverage-plus.numberOfProcessors", source: "#nthreads" }
      - { id: "#bamcoverage-plus.normalizeUsingRPKM", valueFrom: $(true) }
    outputs:
      - id: "#bamcoverage-plus.output_bam_coverage"
  - id: "#bamcoverage-minus"
    run: {$import: "../quant/deeptools-bamcoverage.cwl"}
    scatter: "#bamcoverage-minus.bam"
    inputs:
      - { id: "#bamcoverage-minus.bam", source: "#split_bams.bam_minus_files" }
      - { id: "#bamcoverage-minus.output_suffix", valueFrom: ".norm-minus-pre-negated-bw" }
      - { id: "#bamcoverage-minus.numberOfProcessors", source: "#nthreads" }
      - { id: "#bamcoverage-minus.normalizeUsingRPKM", valueFrom: $(true) }
    outputs:
      - id: "#bamcoverage-minus.output_bam_coverage"
  - id: "#bw2bdg-minus"
    run: {$import: "../quant/bigWigToBedGraph.cwl"}
    scatter: "#bw2bdg-minus.bigwig_file"
    inputs:
      - { id: "#bw2bdg-minus.bigwig_file", source: "#bamcoverage-minus.output_bam_coverage" }
    outputs:
      - id: "#bw2bdg-minus.output_bedgraph"
  - id: "#negate_minus_bdg_norm"
    run: {$import: "../quant/negate-minus-strand-bedgraph.cwl"}
    scatter:
      - "#negate_minus_bdg_norm.bedgraph_file"
      - "#negate_minus_bdg_norm.output_filename"
    scatterMethod: dotproduct
    inputs:
      - { id: "#negate_minus_bdg_norm.bedgraph_file",  source: "#bw2bdg-minus.output_bedgraph" }
      - id: "#negate_minus_bdg_norm.output_filename"
        source: "#basename.basename"
        valueFrom: $(self + ".norm-minus-bdg")
    outputs:
      - id: "#negate_minus_bdg_norm.negated_minus_bdg"
  - id: "#bdg2bw-norm-minus"
    run: {$import: "../quant/bedGraphToBigWig.cwl"}
    scatter: "#bdg2bw-norm-minus.bed_graph"
    inputs:
      - { id: "#bdg2bw-norm-minus.bed_graph", source: "#negate_minus_bdg_norm.negated_minus_bdg" }
      - { id: "#bdg2bw-norm-minus.genome_sizes", source: "#input_genome_sizes" }
      - { id: "#bdg2bw-norm-minus.output_suffix", valueFrom: ".Aligned.minus.norm.bw" }
    outputs:
      - id: "#bdg2bw-norm-minus.output_bigwig"