# Mangrove workflow as step notebooks

`mangrove_workflow_for_cwl.ipynb` turns the whole analysis into a single CWL
CommandLineTool (`mangrove_cli`). To profile the workflow step by step (OGC OSPD 2026,
[process profiles register](https://geolabs.github.io/bblocks-process-profiles/)), the same
analysis is also split into one notebook per processing step under `steps/`. The steps
follow the ones of the W1 Algae Bloom workflow, already profiled in that register.

`ipython2cwl` (with workflow generation) turns each notebook into a CommandLineTool and
chains them into a packed CWL Workflow, `mangrove-workflow-steps`, according to
`workflow.yml`. As in the Algae Bloom application package, each step runs in its own image
(`ghcr.io/geolabs/kindgrove/<step>:<commit>`, e.g. `select-scene`, `download-band`), a thin
layer holding only the step script on top of a base image with the repository environment
(`ghcr.io/geolabs/kindgrove/mangrove-cwl:<commit>`, built by repo2docker from
`requirements.txt`). `parse_aoi` runs in `alpine`.

| # | Step (CWL id) | Source | Six-phase position | W1 Algae Bloom counterpart |
|---|---|---|---|---|
| 0 | `parse_aoi` | `cwl/parse_aoi.cwl` (CWL only) | Filter configuration | (none; same tool as in the profiled `mangrove-workflow`) |
| 1 | `select_scene` | `steps/01_select_scene.ipynb` | Selection / filtering | `select-products-sentinel2` |
| 2 | `download_band` (scatter over `red`, `green`, `nir`) | `steps/02_download_band.ipynb` | Data retrieval | `download-band-sentinel2-stac-item` |
| 3 | `reproject_band` (scatter over the bands) | `steps/03_reproject_band.ipynb` | Pre-processing | `reproject-image` |
| 4 | `calculate_indices` | `steps/04_calculate_indices.ipynb` | Scientific computation | `calculate-band` |
| 5 | `estimate_biomass` | `steps/05_estimate_biomass.ipynb` | Scientific computation | `calculate-band` |
| 6 | `export_stac` | `steps/06_export_stac.ipynb` | Export / aggregation | `plot-image` |

The data passed between steps:

```
aoi ─ parse_aoi ─ west/south/east/north ─┬─ select_scene ─ stac_item ─┬─ download_band ×3 ─ band_file[] ─ reproject_band ×3 ─ reprojected_file[]
                                         │                            │                                                            │
                                         │                            │   calculate_indices ◄──────────────────────────────────────┘
                                         │                            │        │ ndvi_file, ndwi_file, savi_file
                                         │                            └─► estimate_biomass ─ mask, biomass, CSV summaries, analysis_summary
                                         └──────────────────────────────► export_stac ─ stac (Directory: STAC Catalog)
```

## Workflow interface

Same interface as the profiled `mangrove-workflow`: `aoi` (eoap `BBox`),
`cloud_cover_max`, `days_back`, and one output, `stac` (a STAC Catalog). The parameters
that were constants in the single notebook are now optional inputs whose defaults are the
original values: `stac_api`, `collection`, `epsg`, `resolution`, the detection thresholds
(`ndvi_min`, `ndvi_max`, `ndwi_min`, `savi_min`), the allometric coefficients
(`biomass_slope`, `biomass_intercept`) and `carbon_fraction`.

## Differences from the single notebook

- Download reads each band over the study area only (windowed read of the COG), in the
  scene's UTM grid, instead of loading the full scene with `stackstac`. The
  `raster:bands` scale and offset are applied, as `stackstac` does by default.
- Reprojection to EPSG:4326 at 0.0001° (nearest neighbour) is a step of its own. Its grid
  is the study area snapped on the resolution. `stackstac` aligns its grid differently, so
  pixel counts, and therefore areas and totals, can differ slightly between the two
  versions for the same scene.
- `cloud_cover_max` is a `float` (as in the profiled `mangrove-workflow`).
- The mask is written as `uint8` (it was `float64`), and two assets are added to the STAC
  Item: `biomass.tif` and a PNG quicklook. The Item links to the source scene
  (`derived_from`).
- Each step declares its own `ResourceRequirement`. Only `select_scene` and
  `download_band` require network access.

## Generate and run

```bash
pip install "git+https://github.com/gfenoy/ipython2cwl.git@develop"   # with workflow generation
mkdir -p myApplication/cwl_output && cd myApplication
cp -r ../steps ../cwl ../workflow.yml ../requirements.txt ../*for_cwl.ipynb .
jupyter-repo2cwl . -o cwl_output --workflow-manifest workflow.yml \
  --docker-pull ghcr.io/geolabs/kindgrove/mangrove-cwl:dev --per-step-images
cat cwl_output/images.txt      # base image, then one image per step
cwltool --provenance ./PROV-steps cwl_output/mangrove-workflow-steps.cwl \
  ../mangrove_workflow_steps_input.yml
```

Add `--skip-build` to only write the CWL files. Without `--per-step-images`, all the steps
run in the base image, which then holds every script. The notebooks also run top to bottom in
Jupyter, in order, from the same directory. Their input cells hold example values.
