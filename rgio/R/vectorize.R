#' Vectorize Raster Data
#'
#' Convert raster pixels into polygons using GDAL's polygonize functionality.
#'
#' @param src Source raster dataset path.
#' @param dst Destination vector dataset path.
#' @param format Output vector driver (default: "GPKG").
#' @param band Raster band index to polygonize (default: 1).
#' @param field Attribute name to store pixel values (default: "DN").
#' @param connectedness Pixel connectivity used to form polygons (4 or 8).
#' @param mask Optional path to a mask raster; pixels where the mask is zero are ignored.
#' @param co Character vector of dataset creation options forwarded to the GDAL driver.
#'
#' @return Invisibly returns `dst`.
#' @export
rg_vectorize <- function(src, dst, format = "GPKG", band = 1L,
                         field = "DN", connectedness = 8L,
                         mask = NULL, co = NULL) {
  if (!is.character(src) || length(src) != 1) {
    stop("'src' must be a single character string")
  }
  if (!is.character(dst) || length(dst) != 1) {
    stop("'dst' must be a single character string")
  }
  if (!is.character(format) || length(format) != 1) {
    stop("'format' must be a single character string")
  }
  band <- as.integer(band)
  if (length(band) != 1 || band < 1L) {
    stop("'band' must be a positive integer")
  }
  if (!is.character(field) || length(field) != 1) {
    stop("'field' must be a single character string")
  }
  connectedness <- as.integer(connectedness)
  if (!connectedness %in% c(4L, 8L)) {
    stop("'connectedness' must be either 4 or 8", call. = FALSE)
  }
  if (!is.null(mask) && (!is.character(mask) || length(mask) != 1)) {
    stop("'mask' must be NULL or a single character string")
  }
  co <- normalize_options(co)

  invisible(.Call("_rgio_vec", src, dst, format, band, field,
                  connectedness, mask %||% "", co, PACKAGE = "rgio"))
}
