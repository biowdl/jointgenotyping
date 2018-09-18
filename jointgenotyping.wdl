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
        call gatk.CombineGVCFs as combineGVCFs {
            input:
                gvcfFiles = files,
                gvcfFilesIndex = indexes,
                reference = reference,
                outputPath = outputDir + "/scatters/" + basename(bed) + ".g.vcf.gz",
                intervals = [bed]
        }

        File gvcfChunks = combineGVCFs.outputVCF.file
        File gvcfChunkdIndexes = combineGVCFs.outputVCF.index

        call gatk.GenotypeGVCFs as genotypeGvcfs {
            input:
                gvcfFiles = [combineGVCFs.outputVCF.file],
                gvcfFilesIndex = [combineGVCFs.outputVCF.index],
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