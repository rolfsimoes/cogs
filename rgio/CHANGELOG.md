# Changelog

All notable changes to the rgio package will be documented in this file.

## [0.1.0] - 2025-10-23

### Added – Initial Implementation

_First stable cut of rgio with complete GDAL-backed raster/vector IO helpers._

#### Highlights

- Twelve exported R helpers covering raster ingest/egress (`rg_read()`, `rg_write()`), reprojection & mosaicking (`rg_warp()`), translation & COG creation (`rg_translate()`), vector/raster conversion (`rg_rasterize()`, `rg_vectorize()`), VRT management (`rg_vrt_build()`/`rg_vrt_palette()`/`rg_vrt_legend()`), metadata inspection (`rg_info()`), legend/palette utilities, and overview generation (`rg_overviews()`).
- Comprehensive argument normalisation (resampling aliases, NUM_THREADS hints, palette parsing) implemented in `utils.R`.
- Fully implemented C/C++ layer:
  * `_rgio_rd` / `_rgio_wr` – GDAL warp + raster IO and GeoTIFF writing.
  * `_rgio_wp` – `GDALWarpAppOptions` wrapper with distinct warp/creation options and thread detection.
  * `_rgio_tr` – `GDALTranslate` wrapper for format conversion and nodata assignment.
  * `_rgio_rz` / `_rgio_vec` – Rasterize/polygonize helpers with optional masks and connectivity.
  * `_rgio_overviews` / `_rgio_info` – Overview generation and metadata extraction.
  * `_rgio_vf` + palette/legend helpers – VRT build and palette/category manipulation.
  * Shared GDAL init/cleanup in `init.c` + `gdal_utils.cpp`.
- Testthat suite (10 specs) covering argument validation and smoke round-trips for key helpers.
- Roxygen2 documentation regenerated via `roxygen2::roxygenise()` (man pages and NAMESPACE kept in sync).
- README, NEWS, PACKAGE_STRUCTURE, and IMPLEMENTATION_GUIDE updated to describe the GDAL-backed implementation.

#### System Requirements
- R >= 3.5.0 (tested with R 4.5.x)
- GDAL >= 3.0.0 discoverable via `gdal-config`
- C++17-capable toolchain for the VRT module (`vrt.cpp`)

#### Known Limitations
- Automated tests focus on input validation; end-to-end fixtures will be added in future releases once lightweight sample datasets are bundled.
- Windows builds still require manual GDAL toolchain configuration.

#### Planned Enhancements
- Add data-driven integration tests and optional progress reporting.
- Explore `rg_s3_publish()` for MinIO/AWS upload workflows.
- Expand helper set with higher-level raster algebra utilities.
