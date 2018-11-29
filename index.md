---
layout: default
title: Home
version: v0.1
latest: true
---

The workflow can be used to aggregate and genotype GVCF files for multiple
samples using GATK's GenotypeGVCFs.

This workflow is part of [BioWDL](https://biowdl.github.io/)
developed by [the SASC team](http://sasc.lumc.nl/).

## Usage
This workflow can be run using
[Cromwell](http://cromwell.readthedocs.io/en/stable/):
```bash
java -jar cromwell-<version>.jar run -i inputs.json jointgenotyping.wdl
```

### Inputs
Inputs are provided through a JSON file. The minimally required inputs are
described below and a template containing all possible inputs can be generated
using Womtool as described in the
[WOMtool documentation](http://cromwell.readthedocs.io/en/stable/WOMtool/). See
[this page](/inputs.html) for some additional general notes and information
about pipeline inputs.
```json
{
  "JointGenotyping.gvcfFiles": "A list of GVCF files and their indexes (see the example)",
  "JointGenotyping.dbsnpVCF": {
    "file": "A dbSNP VCF file",
    "index": "The index (.tbi) for the dbSNP VCF file"
  },
  "JointGenotyping.outputDir": "The path to the output directory",
  "JointGenotyping.reference": {
    "fasta": "A reference fasta file",
    "fai": "The index for the reference fasta",
    "dict": "The dict file for the reference fasta"
  }
}
```

Some additional inputs that may be of interest are:
```json
{
  "JointGenotyping.mergeGvcfFiles": "Whether or not to output a merged GVCF files, defaults to true",
  "JointGenotyping.scatterSize": "The size of scatter regions (see explanation of scattering below), defaults to 10,000,000",
  "JointGenotyping.vcfBasename": "The basename of the to be outputed VCF files, defaults to 'multisample'",
  "JointGenotyping.scatterList.regions": "The path to a bed file containing the regions be processed"
}
```

#### Example
```json
{
  "JointGenotyping.gvcfFiles": [
    {
      "file": "/home/user/analysis/results/s1.vcf.gz",
      "index": "/home/user/analysis/results/s1.vcf.gz.tbi"
    }, {
      "file": "/home/user/analysis/results/s2.vcf.gz",
      "index": "/home/user/analysis/results/s2.vcf.gz.tbi"
    }
  ],
  "JointGenotyping.dbsnpVCF": {
    "file": "/home/user/genomes/human/dbsnp/dbsnp-151.vcf.gz",
    "index": "/home/user/genomes/human/dbsnp/dbsnp-151.vcf.gz.tbi"
  },
  "JointGenotyping.outputDir": "/home/user/analysis/results/genotyping",
  "JointGenotyping.reference": {
    "fasta": "/home/user/genomes/human/GRCh38.fasta",
    "fai": "/home/user/genomes/human/GRCh38.fasta.fai",
    "dict": "/home/user/genomes/human/GRCh38.dict"
  }
}
```

### Dependency requirements and tool versions
Included in the repository is an `environment.yml` file. This file includes
all the tool version on which the workflow was tested. You can use conda and
this file to create an environment with all the correct tools.

### Output
A multisample VCF file. If `mergeGvcfFiles` is set to `true`, also a 
multisample GVCF file.

## scattering
This pipeline performs scattering to speed up analysis on grid computing
clusters. This is done by splitting the reference genome into regions of
roughly equal size (see the `scatterSize` input). Each of these regions will
be analyzed in separate jobs, allowing them to be processed in parallel.

## Contact
<p>
  <!-- Obscure e-mail address for spammers -->
For any question about running this workflow or feature requests, please use
the
<a href='https://github.com/biowdl/jointgenotyping/issues'>github issue tracker</a>
or contact
<a href='http://sasc.lumc.nl/'>the SASC team</a> directly at: <a href='&#109;&#97;&#105;&#108;&#116;&#111;&#58;&#115;&#97;&#115;&#99;&#64;&#108;&#117;&#109;&#99;&#46;&#110;&#108;'>
&#115;&#97;&#115;&#99;&#64;&#108;&#117;&#109;&#99;&#46;&#110;&#108;</a>.
</p>
