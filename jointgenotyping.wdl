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
        # 500 000 000 gives approximately 6 scatters per sample.
        Int scatterSize = 500000000
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

        File gvcfChunks = if length(files) > 1
            then select_first([combinedGvcfFile])
            else files[0]
        File gvcfChunkdIndexes = if length(files) > 1
            then select_first([combinedGvcfIndex])
            else indexes[0]

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

    # Merge GVCF files
    if (mergeGvcfFiles && length(gvcfFiles) > 1) {
        call picard.MergeVCFs as gatherGvcfs {
            input:
                inputVCFs = gvcfChunks,
                inputVCFsIndexes = gvcfChunkdIndexes,
                outputVcfPath = outputDir + "/" + vcfBasename + ".g.vcf.gz"
        }
    }

    # If only one is given link instead.
    if (mergeGvcfFiles && length(gvcfFiles) == 1) {
        call common.CreateLink as createGVCFlink {
            input:
                inputFile = files[0],
                outputPath = outputDir + "/" + vcfBasename + ".g.vcf.gz"
        }

        call common.CreateLink as createGVCFIndexlink {
            input:
                inputFile = indexes[0],
                outputPath = outputDir + "/" + vcfBasename + ".g.vcf.gz.tbi"
        }
    }

    output {
        IndexedVcfFile vcfFile = gatherVcfs.outputVcf
    }
}