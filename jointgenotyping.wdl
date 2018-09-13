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

        call gatk.GenotypeGVCFs as genotypeGvcfs {
            input:
                gvcfFiles = combineGVCFs.outputGVCF,
                gvcfFileIndexes = combineGVCFs.outputGVCFindex,
                intervals = [bed],
                reference = reference,
                outputPath = outputDir + "/scatters/" + basename(bed) + ".genotyped.vcf.gz",
                dbsnpVCF = dbsnpVCF
        }
    }

    call picard.MergeVCFs as gatherVcfs {
        input:
            inputVCFs = genotypeGvcfs.outputVCF,
            inputVCFsIndexes = genotypeGvcfs.outputVCFindex,
            outputVCFpath = outputDir + "/" + vcfBasename + ".vcf.gz"
    }

    if (mergeGvcfFiles) {
        call picard.MergeVCFs as gatherGvcfs {
            input:
                inputVCFs = combineGVCFs.outputGVCF,
                inputVCFsIndexes = combineGVCFs.outputGVCFindex,
                outputVCFpath = outputDir + "/" + vcfBasename + ".g.vcf.gz"
        }
    }

    output {
        File vcfFile = gatherVcfs.outputVCF
        File vcfFileIndex = gatherVcfs.outputVCFindex
    }
}