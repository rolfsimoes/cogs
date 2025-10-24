#' Build Raster Overviews
#'
#' Create internal or external overviews (pyramids) on an existing raster dataset.
#'
#' @param path Path to GeoTIFF/COG dataset.
#' @param levels Optional integer vector of overview levels (e.g. `c(2, 4, 8)`).
#'   If `NULL`, sensible defaults are chosen based on dataset size.
#' @param resample Resampling method to use for overview generation (default: "nearest").
#' @param external Logical indicating whether to create external overviews (`.ovr` files).
#' @param threads Number of threads to request from GDAL (default: 0 for auto).
#'
#' @return Invisibly returns `path`.
#' @export
rg_overviews <- function(path, levels = NULL,
                         resample = "nearest",
                         external = FALSE,
                         threads = 0L) {
  if (!is.character(path) || length(path) != 1) {
    stop("'path' must be a single character string")
  }
  if (!is.null(levels)) {
    if (!is.numeric(levels) || any(levels <= 1)) {
      stop("'levels' must be numeric values greater than 1", call. = FALSE)
    }
    levels <- as.integer(levels)
  } else {
    levels <- integer()
  }
  resample <- normalize_resample(resample)
  if (!is.logical(external) || length(external) != 1) {
    stop("'external' must be a single logical value")
  }
  threads <- normalize_threads(threads)

  invisible(.Call("_rgio_overviews", path, levels, resample,
                  external, threads, PACKAGE = "rgio"))
}
