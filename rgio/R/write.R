#' Write Raster Data to GeoTIFF
#'
#' Create GeoTIFF files from scalars, matrices, or `rgio_raster` objects using
#' GDAL. When an `rgio_raster` object (as returned by [`rg_read()`]) is supplied,
#' its spatial metadata attributes (`gt`, `width`, `height`, `crs`) are used and
#' one output file is written per list element. When a scalar or matrix is
#' supplied, the metadata must be provided explicitly (except for `width` and
#' `height`, which default to the matrix dimensions).
#'
#' @param x A scalar numeric value, a matrix, a numeric vector of length
#'   `width * height`, or an object inheriting from class `rgio_raster`.
#' @param files Character vector of output file paths. Must be length one for
#'   scalar/vector/matrix input, and the same length as `x` for `rgio_raster`
#'   objects.
#' @param gt Numeric vector of length 6 defining the GDAL geotransform.
#' @param width,height Integer dimensions of the raster (required for scalar and
#'   vector input; inferred from matrices and `rgio_raster` objects).
#' @param crs Character string describing the coordinate reference system. Any
#'   format accepted by GDAL (e.g. `"EPSG:4326"`) is supported.
#' @param datatype Output GDAL data type. One of `"Float64"` (default),
#'   `"Float32"`, `"Int32"`, `"Int16"`, `"UInt32"`, `"UInt16"`, or `"Byte"`.
#' @param nodata Numeric value to use as the dataset nodata value (use
#'   `NA_real_` to omit).
#' @param co Character vector of GDAL creation options (e.g.
#'   `c("COMPRESS=ZSTD", "TILED=YES")`).
#'
#' @return Invisibly returns `files`.
#'
#' @examples
#' tmp <- tempfile(fileext = ".tif")
#' gt <- c(10, 0.1, 0, 20, 0, -0.1)
#'
#' # Write a constant raster
#' rg_write(5, tmp, gt = gt, width = 10, height = 5, crs = "EPSG:4326")
#' unlink(tmp)
#'
#' @export
rg_write <- function(x,
                     files,
                     gt = NULL,
                     width = NULL,
                     height = NULL,
                     crs = NULL,
                     datatype = c("Float64", "Float32", "Int32", "Int16",
                                  "UInt32", "UInt16", "Byte"),
                     nodata = NA_real_,
                     co = NULL) {

  datatype <- match.arg(datatype)

  if (!is.character(files) || length(files) == 0) {
    stop("'files' must be a non-empty character vector")
  }
  co <- normalize_options(co)
  if (length(nodata) != 1) {
    stop("'nodata' must be a single numeric value")
  }

  write_single <- function(data_vec, file_path, w, h, gt_vals, crs_val) {
    if (!is.numeric(gt_vals) || length(gt_vals) != 6) {
      stop("'gt' must be a numeric vector of length 6")
    }
    if (!is.character(crs_val) || length(crs_val) != 1) {
      stop("'crs' must be a single character string")
    }
    if (!is.numeric(data_vec)) {
      stop("Raster data must be numeric")
    }
    if (length(data_vec) != w * h) {
      stop("Raster data length must equal width * height")
    }
    .Call("_rgio_wr",
          enc2utf8(file_path),
          as.numeric(data_vec),
          as.integer(w),
          as.integer(h),
          as.numeric(gt_vals),
          enc2utf8(crs_val),
          datatype,
          as.numeric(nodata),
          enc2utf8(co),
          PACKAGE = "rgio")
  }

  to_row_major <- function(values, w, h) {
    if (is.matrix(values)) {
      if (!missing(w) && !is.null(w) && ncol(values) != w) {
        stop("'width' does not match matrix ncol")
      }
      if (!missing(h) && !is.null(h) && nrow(values) != h) {
        stop("'height' does not match matrix nrow")
      }
      as.numeric(t(values))
    } else {
      vals <- as.numeric(values)
      if (length(vals) != w * h) {
        stop("Raster data length must equal width * height")
      }
      vals
    }
  }

  if (inherits(x, "rgio_raster") || (is.list(x) && !is.null(attr(x, "gt")))) {
    meta_gt <- attr(x, "gt")
    meta_width <- attr(x, "width")
    meta_height <- attr(x, "height")
    meta_crs <- attr(x, "crs")

    if (is.null(meta_gt) || length(meta_gt) != 6) {
      stop("rgio_raster object must have 'gt' attribute of length 6")
    }
    if (is.null(meta_width) || length(meta_width) != 1) {
      stop("rgio_raster object must have scalar 'width' attribute")
    }
    if (is.null(meta_height) || length(meta_height) != 1) {
      stop("rgio_raster object must have scalar 'height' attribute")
    }
    if (is.null(meta_crs) || length(meta_crs) != 1) {
      stop("rgio_raster object must have scalar 'crs' attribute")
    }

    band_list <- as.list(x)
    if (length(files) != length(band_list)) {
      stop("Length of 'files' must match number of bands in 'x'")
    }

    w <- as.integer(meta_width)
    h <- as.integer(meta_height)

    for (i in seq_along(band_list)) {
      band_data <- band_list[[i]]
      band_vec <- to_row_major(band_data, w, h)
      write_single(band_vec, files[[i]], w, h, meta_gt, meta_crs)
    }

    return(invisible(files))
  }

  if (length(files) != 1L) {
    stop("'files' must have length 1 for scalar, vector, or matrix input")
  }

  if (is.null(gt)) {
    stop("'gt' must be supplied for scalar, vector, or matrix input")
  }
  if (is.null(crs)) {
    stop("'crs' must be supplied for scalar, vector, or matrix input")
  }

  if (is.matrix(x)) {
    inferred_height <- nrow(x)
    inferred_width <- ncol(x)
    if (is.null(width)) {
      width <- inferred_width
    }
    if (is.null(height)) {
      height <- inferred_height
    }
    if (width != inferred_width || height != inferred_height) {
      stop("'width' and 'height' must match matrix dimensions")
    }
    width <- as.integer(width)
    height <- as.integer(height)
    data_vec <- to_row_major(x, width, height)
    write_single(data_vec, files[[1]], width, height, gt, crs)
    return(invisible(files))
  }

  if (is.numeric(x) && length(x) == 1L) {
    if (is.null(width) || is.null(height)) {
      stop("'width' and 'height' must be supplied for scalar input")
    }
    width <- as.integer(width)
    height <- as.integer(height)
    data_vec <- rep(as.numeric(x), length.out = width * height)
    write_single(data_vec, files[[1]], width, height, gt, crs)
    return(invisible(files))
  }

  if (is.numeric(x)) {
    if (is.null(width) || is.null(height)) {
      stop("'width' and 'height' must be supplied for vector input")
    }
    width <- as.integer(width)
    height <- as.integer(height)
    data_vec <- to_row_major(x, width, height)
    write_single(data_vec, files[[1]], width, height, gt, crs)
    return(invisible(files))
  }

  stop("Unsupported input type for 'x'")
}
