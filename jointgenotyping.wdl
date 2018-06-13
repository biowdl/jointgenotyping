import "tasks/gatk.wdl" as gatk
import "tasks/biopet.wdl" as biopet
import "tasks/picard.wdl" as picard

workflow JointGenotyping {

    Array[File] gvcfFiles
    Array[File] gvcfIndexes
    String outputDir
    String vcfBasename
    File refFasta
    File refDict
    File refFastaIndex
    Boolean? mergeGvcfFiles
    File dbsnpVCF
    File dbsnpVCFindex

    call biopet.ScatterRegions as scatterList {
        input:
            refFasta = refFasta,
            refDict = refDict,
            outputDirPath = outputDir + "/scatters/"
    }

        scatter (bed in scatterList.scatters) {
            call gatk.CombineGVCFs as combineGVCFs {
                input:
                    gvcfFiles = gvcfFiles,
                    gvcfFileIndexes = gvcfIndexes,
                    refFasta = refFasta,
                    refDict = refDict,
                    refFastaIndex = refFastaIndex,
                    outputPath = outputDir + "/scatters/" + basename(bed) + ".g.vcf.gz",
                    intervals = [bed]
            }

            call gatk.GenotypeGVCFs as genotypeGvcfs {
                input:
                    gvcfFiles = combineGVCFs.outputGVCF,
                    gvcfFileIndexes = combineGVCFs.outputGVCFindex,
                    intervals = [bed],
                    refFasta = refFasta,
                    refDict = refDict,
                    refFastaIndex = refFastaIndex,
                    outputPath = outputDir + "/scatters/" + basename(bed) + ".genotyped.vcf.gz",
                    dbsnpVCF = dbsnpVCF,
                    dbsnpVCFindex = dbsnpVCFindex
            }
        }

        call picard.MergeVCFs as gatherVcfs {
            input:
                inputVCFs = genotypeGvcfs.outputVCF,
                inputVCFsIndexes = genotypeGvcfs.outputVCFindex,
                outputVCFpath = outputDir + "/" + vcfBasename + ".vcf.gz"
        }

        if (select_first([mergeGvcfFiles, true])) {
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