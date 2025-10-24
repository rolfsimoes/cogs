#' Rasterize Vector Files
#'
#' Convert one or many vector files (shapefiles, GeoJSON, etc.) to GeoTIFF tiles in parallel.
#' This function wraps GDAL's rasterization capabilities with multi-threaded processing.
#'
#' @param files Character vector of input vector file paths
#' @param outdir Output directory for rasterized GeoTIFF files
#' @param field Character string specifying the field/attribute to rasterize (default: "class")
#' @param res Numeric vector of length 2 specifying x and y resolution (default: c(0.00025, 0.00025))
#' @param crs Character string specifying the coordinate reference system (default: "EPSG:4326")
#' @param nodata Integer or numeric value for nodata pixels (default: 0L)
#' @param co Character vector of GDAL creation options (default: `c("COMPRESS=ZSTD", "TILED=YES", "BIGTIFF=YES")`)
#' @param threads Integer specifying number of threads (0 = auto, default: 0L)
#'
#' @return Character vector of output file paths
#'
#' @examples
#' \dontrun{
#' # Rasterize a single shapefile
#' rg_rasterize("input.shp", "output_dir", field = "landcover")
#'
#' # Rasterize multiple files in parallel
#' files <- c("file1.shp", "file2.shp", "file3.shp")
#' rg_rasterize(files, "output_dir", threads = 4)
#' }
#'
#' @export
rg_rasterize <- function(files, outdir, field = "class", res = c(0.00025, 0.00025),
                         crs = "EPSG:4326", nodata = 0L,
                         co = c("COMPRESS=ZSTD", "TILED=YES", "BIGTIFF=YES"),
                         threads = 0L) {
  # Input validation
  if (!is.character(files) || length(files) == 0) {
    stop("'files' must be a non-empty character vector")
  }
  if (!is.character(outdir) || length(outdir) != 1) {
    stop("'outdir' must be a single character string")
  }
  if (!is.character(field) || length(field) != 1) {
    stop("'field' must be a single character string")
  }
  if (!is.numeric(res) || length(res) != 2) {
    stop("'res' must be a numeric vector of length 2")
  }
  if (!is.character(crs) || length(crs) != 1) {
    stop("'crs' must be a single character string")
  }
  if (!is.numeric(nodata) && !is.integer(nodata)) {
    stop("'nodata' must be numeric or integer")
  }
  co <- normalize_options(co)
  threads <- normalize_threads(threads)

  # Call C function
  .Call("_rgio_rz", files, outdir, field, res, crs, as.integer(nodata),
        co, threads, PACKAGE = "rgio")
}
