#!/usr/bin/env cwl-runner
# Filter configuration step: splits an OGC BBox (eoap schemas) into the four
# coordinates used by the notebook steps. Taken from the mangrove-workflow of
# GeoLabs/bblocks-eoap-cct (the unused `output_dir` output is dropped).
cwlVersion: v1.2
class: CommandLineTool
id: parse_aoi
label: Parse area of interest
doc: Splits an OGC bounding box into its west, south, east and north coordinates.
baseCommand: echo
arguments:
  - --
requirements:
  InlineJavascriptRequirement: {}
  SchemaDefRequirement:
    types:
      - $import: https://raw.githubusercontent.com/eoap/schemas/main/ogc.yaml
  ResourceRequirement:
    coresMax: 1
    ramMax: 512
hints:
  DockerRequirement:
    dockerPull: alpine:3.22.2
inputs:
  aoi:
    type: https://raw.githubusercontent.com/eoap/schemas/main/ogc.yaml#BBox
    label: Area of interest
    doc: Area of interest defined as a bounding box
outputs:
  west:
    type: float
    outputBinding:
      outputEval: $(inputs.aoi.bbox[0])
  south:
    type: float
    outputBinding:
      outputEval: $(inputs.aoi.bbox[1])
  east:
    type: float
    outputBinding:
      outputEval: $(inputs.aoi.bbox[2])
  north:
    type: float
    outputBinding:
      outputEval: $(inputs.aoi.bbox[3])
