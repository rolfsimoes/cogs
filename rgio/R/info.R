#' Inspect Raster Metadata
#'
#' Retrieve basic metadata about a raster dataset using GDAL.
#'
#' @param path Path to raster dataset.
#'
#' @return A list containing `width`, `height`, `bands`, `dtype`, `gt`, `crs`,
#'   `nodata`, and logical flags indicating presence of `color_table` and `categories`.
#' @export
rg_info <- function(path) {
  if (!is.character(path) || length(path) != 1) {
    stop("'path' must be a single character string")
  }

  .Call("_rgio_info", path, PACKAGE = "rgio")
}
