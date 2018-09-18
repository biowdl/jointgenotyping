/*
 * Copyright (c) 2018 Biowdl
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy of
 * this software and associated documentation files (the "Software"), to deal in
 * the Software without restriction, including without limitation the rights to
 * use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
 * the Software, and to permit persons to whom the Software is furnished to do so,
 * subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
 * FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
 * COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
 * IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

package biowdl.test

import java.io.File

import nl.biopet.utils.biowdl.Pipeline
import nl.biopet.utils.biowdl.references.Reference
import nl.biopet.utils.ngs.vcf.getVcfIndexFile

trait JointGenotyping extends Pipeline with Reference {

  def gvcfFiles: List[File]
  def gvcfIndexes: List[File] = gvcfFiles.map { file =>
    getVcfIndexFile(file)
  }
  def dbsnpFile: Option[File]
  def vcfBasename: Option[String] = None
  def mergeGvcfFiles: Option[Boolean] = None

  override def inputs: Map[String, Any] =
    super.inputs ++
      Map(
        "JointGenotyping.outputDir" -> outputDir.getAbsolutePath,
        "JointGenotyping.reference" -> Map(
          "fasta" -> referenceFasta.getAbsolutePath,
          "fai" -> referenceFastaIndexFile.getAbsolutePath,
          "dict" -> referenceFastaDictFile.getAbsolutePath
        ),
        "JointGenotyping.gvcfFiles" -> gvcfFiles.zip(gvcfIndexes).map {
          case (f, i) =>
            Map("file" -> f.getAbsolutePath, "index" -> i.getAbsolutePath)
        }
      ) ++
      mergeGvcfFiles.map("JointGenotyping.mergeGvcfFiles" -> _) ++
      vcfBasename.map("JointGenotyping.vcfBasename" -> _) ++
      dbsnpFile.map(
        f =>
          "JointGenotyping.dbsnpVCF" -> Map(
            "file" -> f.getAbsolutePath,
            "index" -> getVcfIndexFile(f).getAbsolutePath))

  def startFile: File = new File("./jointgenotyping.wdl")
}
