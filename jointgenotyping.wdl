version 1.0

import "tasks/biopet/biopet.wdl" as biopet
import "tasks/common.wdl" as common
import "tasks/gatk.wdl" as gatk
import "tasks/picard.wdl" as picard
import "tasks/samtools.wdl" as samtools

workflow JointGenotyping {
    input{
        Array[IndexedVcfFile]+ gvcfFiles
        String outputDir
        String vcfBasename = "multisample"
        Reference reference
        Boolean mergeGvcfFiles = true
        IndexedVcfFile dbsnpVCF

        File? regions
        # scatterSize is on number of bases. The human genome has 3 000 000 000 bases.
        # 400 000 000 gives approximately 8 scatters per sample.
        Int scatterSize = 400000000
    }

    call biopet.ScatterRegions as scatterList {
        input:
            reference = reference,
            outputDirPath = outputDir + "/scatters/",
            scatterSize = scatterSize,
            regions = regions
    }

    # Glob messes with order of scatters (10 comes before 1), which causes problems at vcf gathering
    call biopet.ReorderGlobbedScatters as orderedScatters {
        input:
            scatters = scatterList.scatters,
            scatterDir = outputDir + "/scatters/"
    }

    scatter (gvcf in gvcfFiles) {
        File files = gvcf.file
        File indexes = gvcf.index
    }

    scatter (bed in orderedScatters.reorderedScatters) {

        call gatk.CombineGVCFs as combineGVCFs {
            input:
                gvcfFiles = files,
                gvcfFilesIndex = indexes,
                reference = reference,
                outputPath = outputDir + "/scatters/" + basename(bed) + ".g.vcf.gz",
                intervals = [bed]
        }


        File combinedGvcfFile = combineGVCFs.outputVCF.file
        File combinedGvcfIndex = combineGVCFs.outputVCF.index

        call gatk.GenotypeGVCFs as genotypeGvcfs {
            input:
                gvcfFiles = [combinedGvcfFile],
                gvcfFilesIndex = [combinedGvcfIndex],
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
                inputVCFs = combinedGvcfFile,
                inputVCFsIndexes = combinedGvcfIndex,
                outputVcfPath = outputDir + "/" + vcfBasename + ".g.vcf.gz"
        }
    }


    output {
        IndexedVcfFile vcfFile = gatherVcfs.outputVcf
    }
}