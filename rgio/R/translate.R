#' Translate Raster Datasets
#'
#' Lightweight wrapper around GDAL's `gdal_translate` utility for converting datasets,
#' changing formats, or applying simple pixel-space operations.
#'
#' @param src Source raster file path.
#' @param dst Destination raster file path.
#' @param format Optional GDAL driver name for the output dataset (default: `NULL`, meaning reuse source).
#' @param co Character vector of GDAL creation options.
#' @param resample Optional resampling method to apply when resizing (same aliases as [`rg_read()`]).
#' @param nodata Optional numeric value to set as nodata in the output; use `NA` to skip.
#' @param options Additional raw GDAL translate arguments supplied as character vector (e.g. `c("-projwin", ...)`).
#' @param threads Number of threads to request from GDAL (default: 0 for auto).
#'
#' @return Invisibly returns `dst`.
#' @export
rg_translate <- function(src, dst,
                         format = NULL,
                         co = NULL,
                         resample = NULL,
                         nodata = NA_real_,
                         options = character(),
                         threads = 0L) {
  if (!is.character(src) || length(src) != 1) {
    stop("'src' must be a single character string")
  }
  if (!is.character(dst) || length(dst) != 1) {
    stop("'dst' must be a single character string")
  }
  if (!is.null(format)) {
    if (!is.character(format) || length(format) != 1) {
      stop("'format' must be NULL or a single character string")
    }
  } else {
    format <- ""
  }
  co <- normalize_options(co)
  if (!is.null(resample)) {
    resample <- normalize_resample(resample)
  } else {
    resample <- ""
  }
  if (length(nodata) != 1) {
    stop("'nodata' must be a single numeric value (NA allowed)", call. = FALSE)
  }
  nodata <- as.numeric(nodata)
  if (!is.character(options)) {
    stop("'options' must be a character vector")
  }
  threads <- normalize_threads(threads)

  invisible(.Call("_rgio_tr", src, dst, format, resample,
                  nodata, options, co, threads,
                  PACKAGE = "rgio"))
}
