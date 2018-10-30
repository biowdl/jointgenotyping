version 1.0

import "tasks/biopet/biopet.wdl" as biopet
import "tasks/common.wdl" as common
import "tasks/gatk.wdl" as gatk
import "tasks/picard.wdl" as picard
import "tasks/samtools.wdl" as samtools

workflow JointGenotyping {
    input{
        Array[IndexedVcfFile] gvcfFiles
        String outputDir
        String vcfBasename = "multisample"
        Reference reference
        Boolean mergeGvcfFiles = true
        IndexedVcfFile dbsnpVCF

        Int scatterSize = 10000000
    }

    call biopet.ScatterRegions as scatterList {
        input:
            reference = reference,
            outputDirPath = outputDir + "/scatters/",
            scatterSize = scatterSize
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

    call picard.GatherVcfs as gatherVcfs {
        input:
            inputVcfs = chunks,
            inputVcfIndexes = chunkdIndexes,
            outputVcfPath = outputDir + "/" + vcfBasename + ".vcf.gz"
    }

    call samtools.Tabix as indexGatheredVcfs {
        input:
            inputFile = gatherVcfs.outputVcf
    }

    if (mergeGvcfFiles) {
        call picard.GatherVcfs as gatherGvcfs {
            input:
                inputVcfs = gvcfChunks,
                inputVcfIndexes = gvcfChunkdIndexes,
                outputVcfPath = outputDir + "/" + vcfBasename + ".g.vcf.gz"
        }

        call samtools.Tabix as indexGatheredGvcfs {
            input:
                inputFile = gatherGvcfs.outputVcf
        }
    }

    output {
        IndexedVcfFile vcfFile = object {
            file: gatherVcfs.outputVcf,
            index: indexGatheredVcfs.index
        }
    }
}