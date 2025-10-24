# rgio: High-Performance Raster/Vector I/O with GDAL

**rgio** (R + GDAL I/O) is a lean, C-backed R package that provides high-performance raster and vector I/O operations using GDAL. The package offers a minimal, ergonomic interface with short function names inspired by GDAL's command-line tools.

## Features

The package provides a compact toolbox for working with geospatial rasters and vectors:

- **`rg_read()`** · Read rasters into a shared grid defined by bounding box and dimensions
- **`rg_write()`** · Persist scalars, matrices, or `rgio_raster` objects to GeoTIFF
- **`rg_warp()`** · Combine, reproject, resample, or mosaic raster files in any GDAL-supported format
- **`rg_translate()`** · Lightweight wrapper around `gdal_translate()` (e.g., convert to COG, change datatype)
- **`rg_rasterize()`** · Convert vector files (shapefiles, GeoJSON) to GeoTIFF tiles in parallel
- **`rg_vectorize()`** · Polygonize rasters back to vector datasets using GDAL's polygonize API
- **`rg_vrt_build()` / `rg_vrt_palette()` / `rg_vrt_legend()`** · Create and maintain VRT mosaics with palettes and categories
- **`rg_overviews()`** · Build internal or external pyramids for GeoTIFF/COG assets
- **`rg_info()`** · Inspect dataset metadata (dimensions, dtype, CRS, nodata, palette presence)
- **`rg_palette()`** and **`rg_legend()`** · Inspect or attach GDAL color tables and category labels

## Architecture

The package follows a clean separation of concerns:

- **R front-ends** (`R/` directory): Minimal functions that validate arguments and call C entry points
- **C entry points** (`src/*.c`): Registered native routines that interface between R and C++
- **C++ internals** (`src/*.cpp`): GDAL logic, thread pools, and memory management

All functions use GDAL's native capabilities for multi-threaded processing and efficient I/O operations.

## Data Structure

The `rg_read()` function returns data as a flat data frame with numeric vectors for each band, plus spatial metadata stored as attributes:

- `gt`: Geotransform coefficients (6-element numeric vector)
- `width`: Grid width in pixels
- `height`: Grid height in pixels
- `crs`: Coordinate reference system
- `nodata`: Nodata value

This structure provides maximum compatibility with base R while maintaining spatial information.

## System Requirements

- R >= 3.5.0
- GDAL >= 3.0.0

On Ubuntu/Debian:
```bash
sudo apt-get install libgdal-dev
```

On macOS with Homebrew:
```bash
brew install gdal
```

## Installation

```r
# Install from source
devtools::install_github("rolfsimoes/cogs")
```

## Usage Examples

```r
library(rgio)

# Rasterize a shapefile
rg_rasterize("landcover.shp", "output_dir", field = "class", threads = 4)

# Warp and mosaic multiple tiles
files <- c("tile1.tif", "tile2.tif", "tile3.tif")
rg_warp(files, "mosaic.tif", crs = "EPSG:3857", resample = "bilinear")

# Read rasters to a specific grid
bbox <- c(-50, -10, -40, 0)  # xmin, ymin, xmax, ymax
data <- rg_read("input.tif", bbox, width = 1000, height = 1000, crs = "EPSG:4326")

# Apply a color legend
values <- c(1, 2, 3, 4)
colors <- matrix(c(
  255, 0, 0, 255,    # Red
  0, 255, 0, 255,    # Green
  0, 0, 255, 255,    # Blue
  255, 255, 0, 255   # Yellow
), ncol = 4, byrow = TRUE)
labels <- c("Forest", "Water", "Urban", "Agriculture")
rg_legend("landcover.tif", values, colors, labels)

# Write an rgio_raster object back to GeoTIFF tiles (assuming 'value'
# is an object created by rg_read())
files <- c("ndvi.tif", "evi.tif", "b04.tif")
rg_write(value, files)

# Convert a GeoTIFF to Cloud-Optimized GeoTIFF using translate
rg_translate("input.tif", "output_cog.tif", format = "COG",
             co = c("COMPRESS=ZSTD", "LEVEL=12"))

# Build internal overviews for faster visualization
rg_overviews("output_cog.tif")
```

## Design Principles

1. **Short, conventional names**: Function names mirror GDAL's command-line tools (e.g., `rg_rasterize` ~ `gdal_rasterize`)
2. **Minimal overhead**: R functions are thin wrappers around C/C++ implementations
3. **Native GDAL performance**: All heavy lifting is done by GDAL's optimized C++ code
4. **Thread-safe parallelism**: Multi-threaded processing where appropriate
5. **VRT-based optimization**: Internal use of Virtual Rasters for efficient multi-file operations
6. **Base R compatibility**: Returns standard R data structures (data frames, vectors)

## Development Status

This package is currently in early development. The R interface and package structure are complete, but the C/C++ implementations contain stub code that needs to be replaced with full GDAL integration.

### Implementation Roadmap

1. ✅ Package structure and R interface
2. ✅ Test suite for input validation
3. ✅ Documentation (roxygen2)
4. ✅ Native GDAL integrations for `rg_read()`, `rg_write()`, `rg_warp()`, `rg_translate()`, `rg_rasterize()`, `rg_vectorize()`, and VRT helpers
5. ✅ Overviews + metadata inspection utilities (`rg_overviews()`, `rg_info()`)
6. 🚧 High-level helpers (e.g., S3 publishing, batch pipelines)

## License

MIT License - see LICENSE file for details.

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## Author

Rolf Simoes
