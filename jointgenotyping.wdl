import "wdl-tasks/gatk.wdl" as gatk
import "wdl-tasks/biopet.wdl" as biopet
import "wdl-tasks/picard.wdl" as picard

workflow JointGenotyping {

    Array[File] gvcfFiles
    Array[File] gvcfIndexes
    String outputDir
    String vcf_basename
    File ref_fasta
    File ref_dict
    File ref_fasta_index
    Boolean? mergeGvcfFiles = false

    call biopet.ScatterRegions as scatterList {
        input:
            ref_fasta = ref_fasta,
            ref_dict = ref_dict,
            outputDirPath = "."
    }

        scatter (bed in scatterList.scatters) {
            call gatk.CombineGVCFs as combineGVCFs {
                input:
                    gvcf_files = gvcfFiles,
                    gvcf_file_indexes = gvcfIndexes,
                    ref_fasta = ref_fasta,
                    ref_dict = ref_dict,
                    ref_fasta_index = ref_fasta_index,
                    output_basename = vcf_basename,
                    intervals = [bed]
            }

            call gatk.GenotypeGVCFs as genotypeGvcfs {
                input:
                    gvcf_files = combineGVCFs.output_gvcf,
                    gvcf_file_indexes = combineGVCFs.output_gvcf_index,
                    intervals = [bed],
                    ref_fasta = ref_fasta,
                    ref_dict = ref_dict,
                    ref_fasta_index = ref_fasta_index,
                    output_basename = vcf_basename
            }
        }

        call picard.MergeVCFs as gatherVcfs {
            input:
                input_vcfs = genotypeGvcfs.output_vcf,
                input_vcfs_indexes = genotypeGvcfs.output_vcf_index,
                output_vcf_path = outputDir + "/" + vcf_basename + ".vcf.gz"
        }

        if (mergeGvcfFiles) {
            call picard.MergeVCFs as gatherGvcfs {
                input:
                    input_vcfs = combineGVCFs.output_gvcf,
                    input_vcfs_indexes = combineGVCFs.output_gvcf_index,
                    output_vcf_path = outputDir + "/" + vcf_basename + ".g.vcf.gz"
            }
        }

    output {
        File vcf_file = gatherGvcfs.output_vcf
        File vcf_file_index = gatherGvcfs.output_vcf_index
    }
}