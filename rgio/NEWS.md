# rgio 0.1.0

## Initial Release

This is the initial development release of rgio, a high-performance R package for raster/vector I/O using GDAL.

### Features

* Complete R package structure with proper DESCRIPTION, NAMESPACE, tests, and documentation
* GDAL-backed helpers covering the full raster/vector workflow:
  - `rg_read()` / `rg_write()` for ingest + export of raster data
  - `rg_warp()` and `rg_translate()` for reprojection, mosaicking, and format conversion (including COG output)
  - `rg_rasterize()` and `rg_vectorize()` for raster/vector conversion
  - `rg_vrt_build()`, `rg_vrt_palette()`, `rg_vrt_legend()` for VRT management with palettes/categories
  - `rg_overviews()` to build internal/external overviews
  - `rg_info()` / `rg_palette()` / `rg_legend()` for metadata and legend management
* Comprehensive input validation and roxygen2 documentation for each exported helper
* Full testthat suite covering argument validation and smoke tests
* RStudio project configuration (`rgio.Rproj`)

### Development Status

All GDAL-facing routines are implemented in C/C++ with resource management, optional threading hints, and palette/category support. Further integration tests with real datasets are planned for subsequent releases.

### Known Limitations

* Smoke tests currently focus on argument validation; fixtures with sample rasters/vectors are still to be added.
* GDAL must be installed separately and discoverable via `gdal-config` / environment variables.
* Windows support requires pre-configured GDAL toolchain paths.

### Next Steps

* Add integration tests using lightweight sample datasets.
* Explore `rg_s3_publish()` for publishing assets via MinIO/AWS SDKs.
* Continue profiling and add optional progress reporting for long-running workflows.
* Add vignettes and extended usage examples once fixtures are in place.
