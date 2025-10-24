#' rgio: High-Performance Raster/Vector I/O with GDAL
#'
#' The rgio package provides a lean, C-backed R interface to GDAL for high-performance
#' raster and vector I/O operations. It includes functions for rasterizing vector files,
#' warping, translating, and mosaicking rasters, manipulating VRTs, querying dataset metadata,
#' and managing color legends.
#'
#' @section Main Functions:
#' \itemize{
#'   \item \code{\link{rg_read}}: Read rasters to bounding box grids
#'   \item \code{\link{rg_write}}: Save rasters to GeoTIFF
#'   \item \code{\link{rg_warp}}: Warp or mosaic rasters
#'   \item \code{\link{rg_translate}}: Translate rasters between formats or apply pixel operations
#'   \item \code{\link{rg_rasterize}}: Rasterize vector files to GeoTIFF
#'   \item \code{\link{rg_vectorize}}: Vectorize rasters to polygons
#'   \item \code{\link{rg_vrt_build}}: Build VRT mosaics with optional palette injection
#'   \item \code{\link{rg_vrt_palette}}: Inspect or modify VRT color tables
#'   \item \code{\link{rg_vrt_legend}}: Inspect or modify VRT category labels
#'   \item \code{\link{rg_palette}}: Read color tables and labels
#'   \item \code{\link{rg_legend}}: Write legend/color tables to rasters
#'   \item \code{\link{rg_overviews}}: Generate internal or external overviews
#'   \item \code{\link{rg_info}}: Retrieve dataset metadata summary
#' }
#' @name rgio-package
#' @useDynLib rgio, .registration = TRUE
"_PACKAGE"

# nocov start
normalize_resample <- function(resample) {
  if (length(resample) != 1 || is.na(resample)) {
    stop("'resample' must be a single, non-missing value", call. = FALSE)
  }
  key <- tolower(trimws(resample))
  aliases <- c(
    "nearest" = "near",
    "near" = "near",
    "nn" = "near",
    "nearestneighbor" = "near",
    "nearestneighbour" = "near",
    "bilinear" = "bilinear",
    "linear" = "bilinear",
    "cubic" = "cubic",
    "bicubic" = "cubic",
    "cubicspline" = "cubicspline",
    "cubic_spline" = "cubicspline",
    "spline" = "cubicspline",
    "lanczos" = "lanczos",
    "average" = "average",
    "mean" = "average",
    "mode" = "mode",
    "med" = "med",
    "median" = "med",
    "max" = "max",
    "maximum" = "max",
    "min" = "min",
    "minimum" = "min",
    "sum" = "sum",
    "rms" = "rms",
    "q1" = "q1",
    "q3" = "q3"
  )
  canonical <- aliases[key]
  if (length(canonical) == 0L || is.na(canonical)) {
    stop(sprintf("Unsupported resampling method '%s'", resample), call. = FALSE)
  }
  unname(canonical)
}

normalize_threads <- function(threads) {
  if (length(threads) == 0 || is.null(threads)) {
    return(0L)
  }
  if (length(threads) != 1 || is.na(threads) || !is.numeric(threads)) {
    stop("'threads' must be a single, non-missing value", call. = FALSE)
  }
  val <- as.integer(threads)
  if (val < 0L) {
    stop("'threads' must be >= 0", call. = FALSE)
  }
  val
}

normalize_options <- function(x) {
  if (is.null(x)) {
    return(character())
  }
  if (!is.character(x)) {
    x <- as.character(x)
  }
  stats::setNames(trimws(x), NULL)
}

extract_palette_spec <- function(palette, categories = NULL) {
  if (is.null(palette)) {
    return(list(values = integer(), colors = matrix(integer(0), ncol = 4)))
  }

  normalize_colors <- function(mat) {
    if (!is.numeric(mat)) {
      mat <- as.numeric(mat)
    }
    mat <- matrix(as.integer(mat), ncol = 4)
    if (any(mat < 0 | mat > 255, na.rm = TRUE)) {
      stop("Palette colors must be in the range 0-255", call. = FALSE)
    }
    mat
  }

  if (is.list(palette) && !is.data.frame(palette) && !is.matrix(palette)) {
    values <- palette$values %||% palette$indices
    colors <- palette$colors %||% palette$rgba
    if (is.null(values) || is.null(colors)) {
      stop("List palette inputs must contain 'values' and 'colors'", call. = FALSE)
    }
    colors <- normalize_colors(colors)
    if (nrow(colors) != length(values)) {
      stop("'palette$values' must align with number of rows in 'palette$colors'", call. = FALSE)
    }
    values <- as.integer(values)
  } else if (is.data.frame(palette)) {
    col_names <- tolower(names(palette))
    value_idx <- match("value", col_names)
    if (is.na(value_idx)) {
      stop("Palette data frames must include a 'value' column", call. = FALSE)
    }
    rgba_idx <- match(c("r", "g", "b", "a"), col_names)
    if (any(is.na(rgba_idx))) {
      stop("Palette data frames must include 'r', 'g', 'b', and 'a' columns", call. = FALSE)
    }
    values <- as.integer(palette[[value_idx]])
    colors <- normalize_colors(as.matrix(palette[rgba_idx]))
  } else if (is.matrix(palette)) {
    if (ncol(palette) != 4) {
      stop("Palette matrices must have 4 columns (R, G, B, A)", call. = FALSE)
    }
    colors <- normalize_colors(palette)
    row_ids <- rownames(palette)
    if (is.null(row_ids)) {
      values <- seq_len(nrow(palette)) - 1L
    } else {
      values <- as.integer(row_ids)
      if (anyNA(values)) {
        stop("Palette matrix row names must be coercible to integers", call. = FALSE)
      }
    }
  } else {
    stop("Unsupported palette input; use matrix, data frame, or list with values/colors", call. = FALSE)
  }

  if (!is.null(categories)) {
    if (length(categories) != length(values)) {
      stop("'categories' must match the number of palette entries", call. = FALSE)
    }
    categories <- as.character(categories)
  }

  list(values = values, colors = colors, categories = categories)
}

`%||%` <- function(x, y) if (!is.null(x)) x else y
# nocov end
