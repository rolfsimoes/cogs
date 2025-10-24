#' Warp or Mosaic Rasters
#'
#' Combine, reproject, resample, or mosaic raster files using GDAL's warp functionality.
#' Can output standard GeoTIFF or Cloud-Optimized GeoTIFF (COG) format.
#'
#' @param src Character vector of source raster file paths
#' @param dst Character string specifying the destination file path
#' @param tr Numeric vector of length 2 specifying target resolution (default: c(0.00025, 0.00025))
#' @param crs Character string specifying the target coordinate reference system (default: "EPSG:4326")
#' @param resample Character string specifying resampling method (default: "nearest").
#'   Accepts the same aliases as [`rg_read()`].
#' @param dstnodata Numeric value for destination nodata (default: `NA_real_`, meaning leave unset).
#' @param wo Character vector of GDAL warp options (e.g. `"NUM_THREADS=ALL_CPUS"`).
#' @param co Character vector of GDAL creation options (e.g. `"COMPRESS=ZSTD"`).
#' @param format Character string specifying output GDAL driver name (default: "GTiff").
#' @param overwrite Logical indicating whether to overwrite existing files (default: FALSE)
#' @param threads Number of threads to request from GDAL (default: 0 for auto)
#'
#' @return Character string of output file path (invisibly)
#'
#' @examples
#' \dontrun{
#' # Warp a single raster to a new CRS
#' rg_warp("input.tif", "output.tif", crs = "EPSG:3857")
#'
#' # Mosaic multiple rasters
#' files <- c("tile1.tif", "tile2.tif", "tile3.tif")
#' rg_warp(files, "mosaic.tif", resample = "bilinear")
#'
#' # Create a Cloud-Optimized GeoTIFF
#' rg_warp("input.tif", "output_cog.tif", format = "COG",
#'         co = c("COMPRESS=ZSTD", "LEVEL=15"))
#' }
#'
#' @export
rg_warp <- function(src, dst, tr = c(0.00025, 0.00025), crs = "EPSG:4326",
                    resample = "nearest", dstnodata = NA_real_,
                    wo = NULL, co = NULL,
                    format = "GTiff", overwrite = FALSE,
                    threads = 0L) {
  # Input validation
  if (!is.character(src) || length(src) == 0) {
    stop("'src' must be a non-empty character vector")
  }
  if (!is.character(dst) || length(dst) != 1) {
    stop("'dst' must be a single character string")
  }
  if (!is.numeric(tr) || length(tr) != 2) {
    stop("'tr' must be a numeric vector of length 2")
  }
  if (!is.character(crs) || length(crs) != 1) {
    stop("'crs' must be a single character string")
  }
  resample <- normalize_resample(resample)
  threads <- normalize_threads(threads)
  wo <- normalize_options(wo)
  co <- normalize_options(co)
  if (!is.numeric(dstnodata) || length(dstnodata) != 1) {
    stop("'dstnodata' must be a single numeric value (NA allowed)", call. = FALSE)
  }
  dstnodata <- as.numeric(dstnodata)
  if (!is.character(format) || length(format) != 1) {
    stop("'format' must be a single character string")
  }
  if (!is.logical(overwrite) || length(overwrite) != 1) {
    stop("'overwrite' must be a single logical value")
  }

  # Call C function
  invisible(.Call("_rgio_wp", src, dst, tr, crs, resample, dstnodata,
                  wo, co, threads, format, overwrite, PACKAGE = "rgio"))
}
