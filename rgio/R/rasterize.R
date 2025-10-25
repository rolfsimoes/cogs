#' Rasterize Vector Layers with GDAL
#'
#' Converts one or more vector datasets (e.g., Shapefile, GeoJSON, GPKG) into
#' raster tiles using GDAL's rasterization engine. The function supports
#' both **GeoTIFF** and **Cloud-Optimized GeoTIFF (COG)** outputs and
#' allows explicit control over pixel size, projection, data type, and
#' compression options.
#'
#' This is a lightweight, high-performance wrapper around GDAL’s
#' `RasterizeLayers()` API. It is optimized for use in large-scale
#' parallel pipelines where intermediate data are stored in tiled,
#' compressed GeoTIFFs or COGs.
#'
#' @param files Character vector of input vector file paths.
#'   Each file must contain at least one polygon, line, or point layer.
#' @param outdir Character string: output directory for rasterized files.
#'   Each input vector produces one raster file.
#' @param value Numeric scalar burn value used when \code{ro} does not
#'   specify an attribute field (default: \code{1}).
#' @param field Character name of the attribute to burn into the raster.
#'   If NULL or not found in the vector layer, `value` is used.
#' @param res Numeric vector of length two giving the x- and y-resolution
#'   of the output raster (e.g., \code{c(0.00025, 0.00025)}).
#' @param crs Character string specifying the coordinate reference system,
#'   either as an EPSG code (e.g., \code{"EPSG:4326"}) or PROJ/WKT string.
#' @param nodata Integer or numeric value assigned to nodata pixels
#'   (default: \code{0L}).
#' @param dtype Character string indicating the GDAL data type for the
#'   raster band. Typical values include:
#'   \code{"Byte"}, \code{"UInt16"}, \code{"Int16"},
#'   \code{"UInt32"}, \code{"Int32"}, \code{"Float32"}, or \code{"Float64"}.
#'   (default: \code{"UInt16"}).
#' @param format Character string specifying the GDAL output format,
#'   usually \code{"GTiff"} or \code{"COG"} (default: \code{"GTiff"}).
#' @param ro Character vector of GDAL rasterization options. Examples:
#'   \code{c("ATTRIBUTE=class", "ALL_TOUCHED=TRUE")}.
#'   See \code{gdal_rasterize --help} for supported options.
#' @param co Character vector of GDAL creation options controlling output
#'   compression, tiling, and block size. Examples:
#'   \code{c("COMPRESS=ZSTD", "TILED=YES", "BIGTIFF=YES")}.
#' @param threads Integer number of threads to use for GDAL internal
#'   operations (\code{0} = use all available CPUs, default: \code{0L}).
#'
#' @return A character vector giving the full file paths of the output rasters.
#'
#' @section Details:
#' Each input vector file is processed independently. Rasterization is
#' performed using GDAL’s internal multithreading when available.
#' The raster grid is determined from the vector extent and the specified
#' resolution (\code{res}). If both resolution and pixel dimensions
#' (\code{width}/\code{height}) are provided internally, resolution takes
#' precedence.
#'
#' For attribute-based rasterization, include an \code{"ATTRIBUTE=..."}
#' entry in \code{ro}. Otherwise, a constant burn value (from \code{value})
#' is applied.
#'
#' @examples
#' \dontrun{
#' # Rasterize a single shapefile to GeoTIFF
#' rg_rasterize(
#'   files   = "input.shp",
#'   outdir  = "out",
#'   res     = c(0.00025, 0.00025),
#'   crs     = "EPSG:4326",
#'   dtype   = "Byte",
#'   format  = "GTiff"
#' )
#'
#' # Rasterize multiple files in parallel using all CPUs
#' files <- c("a.shp", "b.shp", "c.shp")
#' rg_rasterize(
#'   files   = files,
#'   outdir  = "out",
#'   dtype   = "UInt16",
#'   format  = "COG",
#'   threads = 0L
#' )
#' }
#'
#' @seealso
#' [gdal_rasterize](https://gdal.org/programs/gdal_rasterize.html),
#' [GDALRasterizeLayers](https://gdal.org/api/raster_c_api.html),
#' and \code{\link{rg_warp}} for reprojection and mosaicking.
#'
#' @export
rg_rasterize <- function(files,
                         outdir,
                         value = 1,
                         field = NULL,
                         res = c(0.00025, 0.00025),
                         crs = "EPSG:4326",
                         nodata = 0L,
                         dtype = "UInt16",
                         format = "GTiff",
                         ro = c("ALL_TOUCHED=FALSE"),
                         co = c("COMPRESS=ZSTD", "TILED=YES", "BIGTIFF=YES"),
                         threads = 0L) {
  # ---- Input validation ----
  if (!is.character(files) || length(files) == 0) {
    stop("'files' must be a non-empty character vector")
  }

  if (!is.character(outdir) || length(outdir) != 1) {
    stop("'outdir' must be a single character string")
  }

  if (!is.numeric(res) || length(res) != 2) {
    stop("'res' must be a numeric vector of length 2")
  }

  if (!is.character(crs) || length(crs) != 1) {
    stop("'crs' must be a single character string")
  }

  if (!is.character(dtype) || length(dtype) != 1) {
    stop("'dtype' must be a single character string")
  }

  if (!is.character(format) || length(format) != 1) {
    stop("'format' must be a single character string")
  }

  if (!is.numeric(nodata) && !is.integer(nodata)) {
    stop("'nodata' must be numeric or integer")
  }

  if (!is.null(field) && (!is.character(field) || length(field) != 1)) {
    stop("'field' must be a single character string or NULL")
  }

  caps <- rg_gdal_capabilities(format)
  if (!caps$has_create) {
    stop(sprintf("Driver '%s' does not support Create(); use 'GTiff' instead.", format))
  }

  # ---- Normalize optional arguments ----
  co <- normalize_options(co)
  ro <- normalize_options(ro)
  threads <- normalize_threads(threads)

  # ---- Call C entry point ----
  .Call(
    "_rgio_rz",
    files,
    outdir,
    as.numeric(value),
    if (is.null(field)) "" else field,
    res,
    crs,
    as.integer(nodata),
    dtype,
    format,
    ro,
    co,
    as.integer(threads),
    PACKAGE = "rgio"
  )
}
