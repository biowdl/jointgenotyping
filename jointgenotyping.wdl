version 1.0

import "tasks/gatk.wdl" as gatk
import "tasks/biopet/biopet.wdl" as biopet
import "tasks/picard.wdl" as picard
import "tasks/common.wdl" as common

workflow JointGenotyping {
    input{
        Array[IndexedVcfFile] gvcfFiles
        String outputDir
        String vcfBasename = "multisample"
        Reference reference
        Boolean mergeGvcfFiles = true
        IndexedVcfFile dbsnpVCF
    }

    call biopet.ScatterRegions as scatterList {
        input:
            reference = reference,
            outputDirPath = outputDir + "/scatters/"
    }

    scatter (gvcf in gvcfFiles) {
        File files = gvcf.file
        File indexes = gvcf.index
    }

    scatter (bed in scatterList.scatters) {
        if (length(files) > 1) {
            call gatk.CombineGVCFs as combineGVCFs {
                input:
                    gvcfFiles = files,
                    gvcfFilesIndex = indexes,
                    reference = reference,
                    outputPath = outputDir + "/scatters/" + basename(bed) + ".g.vcf.gz",
                    intervals = [bed]
            }

            # Workaround optional Struct member access
            File combinedGvcfFile = combineGVCFs.outputVCF.file
            File combinedGvcfIndex = combineGVCFs.outputVCF.index
        }

        if (length(files) <= 1) {
            call common.CreateLink as createGVCFlink {
                input:
                    inputFile = files[0],
                    outputPath = outputDir + "/scatters/" + basename(bed) + ".g.vcf.gz"
            }

            call common.CreateLink as createGVCFIndexlink {
                input:
                    inputFile = indexes[0],
                    outputPath = outputDir + "/scatters/" + basename(bed) + ".g.vcf.gz.tbi"
            }
        }

        File gvcfChunks = if length(files) > 1
            then select_first([combinedGvcfFile])
            else select_first([createGVCFlink.link])
        File gvcfChunkdIndexes = if length(files) > 1
            then select_first([combinedGvcfIndex])
            else select_first([createGVCFIndexlink.link])

        call gatk.GenotypeGVCFs as genotypeGvcfs {
            input:
                gvcfFiles = [gvcfChunks],
                gvcfFilesIndex = [gvcfChunkdIndexes],
                intervals = [bed],
                reference = reference,
                outputPath = outputDir + "/scatters/" + basename(bed) + ".genotyped.vcf.gz",
                dbsnpVCF = dbsnpVCF
        }

        File chunks = genotypeGvcfs.outputVCF.file
        File chunkdIndexes = genotypeGvcfs.outputVCF.index
    }

    call picard.MergeVCFs as gatherVcfs {
        input:
            inputVCFs = chunks,
            inputVCFsIndexes = chunkdIndexes,
            outputVcfPath = outputDir + "/" + vcfBasename + ".vcf.gz"
    }

    if (mergeGvcfFiles) {
        call picard.MergeVCFs as gatherGvcfs {
            input:
                inputVCFs = gvcfChunks,
                inputVCFsIndexes = gvcfChunkdIndexes,
                outputVcfPath = outputDir + "/" + vcfBasename + ".g.vcf.gz"
        }
    }

    output {
        IndexedVcfFile vcfFile = gatherVcfs.outputVcf
    }
}