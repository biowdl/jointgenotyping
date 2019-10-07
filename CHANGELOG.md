Changelog
==========

<!--

Newest changes should be on top.

This document is user facing. Please word the changes in such a way
that users understand how the changes affect the new version.
-->

version 1.1.0-dev
---------------------------
+ Update tasks so they pass the correct memory requirements to the 
  execution engine. Memory requirements are set on a per-task (not
  per-core) basis.
+ Fixed a bug which caused a name collision error when parsing
  `jointgenotyping.wdl` with miniwdl 

version 1.0.0
---------------------------
+ Update documentation to reflect latest changes.