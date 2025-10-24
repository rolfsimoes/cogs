#' Read Raster Color Table
#'
#' Retrieve the RGBA color entries and optional category labels from the first
#' band of a raster dataset.
#'
#' @param file Character string with the path to a raster dataset.
#' @param indices Integer vector of palette indices to retrieve.
#'
#' @return A list with two elements: `colors`, an integer matrix of size
#'   `length(indices) x 4` (columns correspond to R, G, B, A), and `labels`, a
#'   character vector containing category names (or `NA` when not available).
#'
#' @examples
#' \dontrun{
#' pal <- rg_palette("raster_with_palette.tif", 0:5)
#' pal$colors
#' pal$labels
#' }
#'
#' @export
rg_palette <- function(file, indices) {
  if (!is.character(file) || length(file) != 1) {
    stop("'file' must be a single character string")
  }
  if (!is.integer(indices)) {
    indices <- as.integer(indices)
  }
  .Call("_rgio_pal", enc2utf8(file), indices, PACKAGE = "rgio")
}
