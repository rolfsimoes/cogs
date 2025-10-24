#' Build Virtual Raster (VRT)
#'
#' Generate a Virtual Raster (VRT) representing a grid or mosaic. Optionally inject a palette
#' and category labels directly into the resulting XML.
#'
#' @param src Character vector of source raster file paths.
#' @param bbox Numeric vector of length 4 specifying bounding box (xmin, ymin, xmax, ymax).
#' @param width,height Integer dimensions of the VRT grid in pixels.
#' @param crs Character string specifying the coordinate reference system.
#' @param options Named list of GDALBuildVRT options (default: `list()`).
#' @param palette Optional palette specification (matrix/data frame/list) used to populate a color table.
#' @param categories Optional character vector of category labels aligned with `palette`.
#'
#' @return Character string specifying the path to the created VRT file.
#'
#' @examples
#' \dontrun{
#' files <- c("tile1.tif", "tile2.tif", "tile3.tif")
#' bbox <- c(-50, -10, -40, 0)
#' palette <- data.frame(
#'   value = 0:3,
#'   r = c(255, 0, 0, 255),
#'   g = c(255, 255, 0, 255),
#'   b = c(255, 0, 255, 0),
#'   a = 255
#' )
#' vrt <- rg_vrt_build(files, bbox, width = 1000, height = 1000,
#'                     crs = "EPSG:4326", palette = palette)
#' }
#'
#' @export
rg_vrt_build <- function(src, bbox, width, height, crs,
                         options = list(),
                         palette = NULL, categories = NULL) {
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
  if (!is.list(options)) {
    stop("'options' must be a list")
  }

  spec <- NULL
  if (!is.null(palette) || !is.null(categories)) {
    spec <- extract_palette_spec(palette, categories)
  }

  vrt_path <- .Call("_rgio_vf", src, bbox, as.integer(width), as.integer(height),
                    crs, options, PACKAGE = "rgio")

  if (!is.null(spec) && length(spec$values) > 0) {
    rg_vrt_palette(vrt_path, palette = spec)
    if (!is.null(spec$categories)) {
      rg_vrt_legend(vrt_path, values = spec$values, labels = spec$categories)
    }
  }

  vrt_path
}

#' Inspect or Update VRT Palette
#'
#' Retrieve or replace the color table stored within a VRT.
#'
#' @param file Path to VRT file.
#' @param palette Optional palette specification (matrix/data frame/list). Omit to read instead of write.
#'
#' @return When reading, returns a list with `values` and `colors`. When writing, invisibly returns `file`.
#' @export
rg_vrt_palette <- function(file, palette = NULL) {
  if (!is.character(file) || length(file) != 1) {
    stop("'file' must be a single character string")
  }
  if (is.null(palette)) {
    return(.Call("_rgio_vrt_palette_get", file, PACKAGE = "rgio"))
  }
  spec <- extract_palette_spec(palette)
  if (length(spec$values) == 0) {
    stop("'palette' must contain at least one entry", call. = FALSE)
  }
  .Call("_rgio_vrt_palette_set", file, as.integer(spec$values),
        as.integer(spec$colors), nrow(spec$colors), PACKAGE = "rgio")
  invisible(file)
}

#' Inspect or Update VRT Categories
#'
#' Retrieve or replace category labels stored in a VRT color table.
#'
#' @param file Path to VRT file.
#' @param values Optional integer vector of palette indices to update. Omit alongside `labels`
#'   to read existing categories.
#' @param labels Optional character vector of category labels corresponding to `values`.
#'
#' @return When reading, returns a character vector of labels indexed by palette entry.
#'   When writing, invisibly returns `file`.
#' @export
rg_vrt_legend <- function(file, values = NULL, labels = NULL) {
  if (!is.character(file) || length(file) != 1) {
    stop("'file' must be a single character string")
  }
  if (is.null(values) && is.null(labels)) {
    return(.Call("_rgio_vrt_legend_get", file, PACKAGE = "rgio"))
  }
  if (is.null(values) || is.null(labels)) {
    stop("Both 'values' and 'labels' must be supplied to update the legend", call. = FALSE)
  }
  if (length(values) != length(labels)) {
    stop("'values' and 'labels' must have the same length", call. = FALSE)
  }
  .Call("_rgio_vrt_legend_set", file, as.integer(values),
        as.character(labels), PACKAGE = "rgio")
  invisible(file)
}
