#' Write Legend / Color Table
#'
#' Attach a color table and category labels to a GeoTIFF or VRT file.
#' This function uses GDAL's color table functionality to add visualization metadata.
#'
#' @param file Character string specifying the target file path (GTiff or VRT)
#' @param values Integer vector of pixel values to assign colors
#' @param colors_rgba Matrix or data frame with 4 columns (R, G, B, A) specifying RGBA colors (0-255)
#' @param labels Character vector of category labels corresponding to values (optional, default: NULL)
#'
#' @return NULL (invisibly). The function modifies the file in place.
#'
#' @examples
#' \dontrun{
#' # Create a simple color table
#' values <- c(1, 2, 3, 4)
#' colors <- matrix(c(
#'   255, 0, 0, 255,    # Red
#'   0, 255, 0, 255,    # Green
#'   0, 0, 255, 255,    # Blue
#'   255, 255, 0, 255   # Yellow
#' ), ncol = 4, byrow = TRUE)
#' labels <- c("Forest", "Water", "Urban", "Agriculture")
#'
#' rg_legend("landcover.tif", values, colors, labels)
#'
#' # Without labels
#' rg_legend("landcover.tif", values, colors)
#' }
#'
#' @export
rg_legend <- function(file, values, colors_rgba, labels = NULL) {
  # Input validation
  if (!is.character(file) || length(file) != 1) {
    stop("'file' must be a single character string")
  }
  if (!is.numeric(values) && !is.integer(values)) {
    stop("'values' must be numeric or integer vector")
  }
  
  # Convert colors to matrix if needed
  if (is.data.frame(colors_rgba)) {
    colors_rgba <- as.matrix(colors_rgba)
  }
  if (!is.matrix(colors_rgba) || ncol(colors_rgba) != 4) {
    stop("'colors_rgba' must be a matrix or data frame with 4 columns (R, G, B, A)")
  }
  if (nrow(colors_rgba) != length(values)) {
    stop("Number of rows in 'colors_rgba' must match length of 'values'")
  }
  
  # Validate labels if provided
  if (!is.null(labels)) {
    if (!is.character(labels)) {
      stop("'labels' must be a character vector or NULL")
    }
    if (length(labels) != length(values)) {
      stop("Length of 'labels' must match length of 'values'")
    }
  } else {
    labels <- character(0)
  }

  # Call C function
  invisible(.Call("_rgio_lg", file, as.integer(values), colors_rgba, labels,
                  PACKAGE = "rgio"))
}
