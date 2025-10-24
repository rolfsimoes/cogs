#' Read Rasters to Bounding Box Grid
#'
#' Read one or more raster files into a shared grid defined by bounding box, width, height, and CRS.
#' Returns a data frame with numeric vectors for each band, plus spatial metadata as attributes.
#'
#' @param src Character vector of source raster file paths
#' @param bbox Numeric vector of length 4 specifying bounding box (xmin, ymin, xmax, ymax)
#' @param width Integer specifying the width of the output grid in pixels
#' @param height Integer specifying the height of the output grid in pixels
#' @param crs Character string specifying the coordinate reference system
#' @param resample Character string specifying resampling method (default: "nearest").
#'   Accepts common aliases such as "near", "bilinear", "cubic", "cubicspline", "lanczos",
#'   "average", "mode", "min", "max", "med", "sum", "rms", "q1", "q3".
#' @param nodata Numeric value to use for nodata pixels (default: NA_real_)
#' @param threads Integer specifying number of threads (0 = auto, default: 0L)
#' @param wo Character vector of additional GDAL warp options (default: `NULL`).
#'
#' @return A data frame with one column per band, containing numeric pixel values.
#'   Spatial metadata is stored in attributes:
#'   \itemize{
#'     \item \code{gt}: Geotransform coefficients (numeric vector of length 6)
#'     \item \code{width}: Grid width in pixels
#'     \item \code{height}: Grid height in pixels
#'     \item \code{crs}: Coordinate reference system
#'     \item \code{nodata}: Nodata value
#'   }
#'
#' @examples
#' \dontrun{
#' # Read a single raster to a specific grid
#' bbox <- c(-50, -10, -40, 0)  # xmin, ymin, xmax, ymax
#' data <- rg_read("input.tif", bbox, width = 1000, height = 1000, crs = "EPSG:4326")
#'
#' # Read multiple rasters with bilinear resampling
#' files <- c("band1.tif", "band2.tif", "band3.tif")
#' data <- rg_read(files, bbox, width = 500, height = 500,
#'                 crs = "EPSG:4326", resample = "bilinear")
#'
#' # Access spatial metadata
#' attr(data, "gt")
#' attr(data, "crs")
#' }
#'
#' @export
rg_read <- function(src, bbox, width, height, crs,
                    resample = "nearest", nodata = NA_real_,
                    threads = 0L, wo = NULL) {
  # Input validation
  if (!is.character(src) || length(src) == 0) {
    stop("'src' must be a non-empty character vector")
  }
  if (!is.numeric(bbox) || length(bbox) != 4) {
    stop("'bbox' must be a numeric vector of length 4 (xmin, ymin, xmax, ymax)")
  }
  if (!is.numeric(width) && !is.integer(width)) {
    stop("'width' must be numeric or integer")
  }
  if (!is.numeric(height) && !is.integer(height)) {
    stop("'height' must be numeric or integer")
  }
  if (!is.character(crs) || length(crs) != 1) {
    stop("'crs' must be a single character string")
  }
  resample <- normalize_resample(resample)
  if (!is.numeric(nodata) || length(nodata) != 1) {
    stop("'nodata' must be a single numeric value")
  }
  threads <- normalize_threads(threads)
  wo <- normalize_options(wo)

  # Call C function
  .Call("_rgio_rd", src, bbox, as.integer(width), as.integer(height),
        crs, resample, nodata, threads, wo,
        PACKAGE = "rgio")
}
