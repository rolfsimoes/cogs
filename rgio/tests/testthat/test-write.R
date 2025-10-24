compute_bbox <- function(gt, width, height) {
  xmin <- gt[1]
  ymax <- gt[4]
  xmax <- gt[1] + width * gt[2]
  ymin <- gt[4] + height * gt[6]
  c(xmin, ymin, xmax, ymax)
}

test_that("rg_write() validates input", {
  expect_error(
    rg_write(list(), character()),
    "'files' must be a non-empty character vector"
  )

  expect_error(
    rg_write(1, tempfile(fileext = ".tif")),
    "'gt' must be supplied"
  )

  expect_error(
    rg_write(matrix(1:4, nrow = 2), tempfile(fileext = ".tif"),
             gt = rep(0, 6), crs = "EPSG:4326", width = 3, height = 3),
    "must match matrix dimensions"
  )

  obj <- list(runif(4), runif(4))
  attr(obj, "gt") <- c(0, 1, 0, 2, 0, -1)
  attr(obj, "width") <- 2L
  attr(obj, "height") <- 2L
  attr(obj, "crs") <- "EPSG:4326"
  class(obj) <- "rgio_raster"

  expect_error(
    rg_write(obj, tempfile(fileext = ".tif")),
    "Length of 'files'"
  )
})

test_that("rg_write() writes constant rasters", {
  tif <- tempfile(fileext = ".tif")
  on.exit(unlink(tif), add = TRUE)

  gt <- c(10, 0.5, 0, 5, 0, -0.5)
  width <- 4L
  height <- 3L

  rg_write(7, tif, gt = gt, width = width, height = height, crs = "EPSG:4326")

  bbox <- compute_bbox(gt, width, height)
  raster <- rg_read(tif, bbox, width, height, "EPSG:4326")
  expect_true(all(vapply(raster, function(x) isTRUE(all.equal(x, rep(7, width * height))), logical(1))))
})

test_that("rg_write() handles matrix input", {
  tif <- tempfile(fileext = ".tif")
  on.exit(unlink(tif), add = TRUE)

  matrix_vals <- matrix(c(1, 2, 3, 4), nrow = 2, byrow = TRUE)
  gt <- c(0, 1, 0, 2, 0, -1)

  rg_write(matrix_vals, tif, gt = gt, crs = "EPSG:4326")

  bbox <- compute_bbox(gt, ncol(matrix_vals), nrow(matrix_vals))
  raster <- rg_read(tif, bbox, ncol(matrix_vals), nrow(matrix_vals), "EPSG:4326")
  expect_equal(raster[[1]], as.numeric(t(matrix_vals)))
})

test_that("rg_write() writes rgio_raster objects", {
  width <- 3L
  height <- 2L
  gt <- c(100, 10, 0, 200, 0, -10)

  value <- list(
    ndvi = runif(width * height),
    evi  = runif(width * height)
  )
  attr(value, "gt") <- gt
  attr(value, "width") <- width
  attr(value, "height") <- height
  attr(value, "crs") <- "EPSG:4326"
  class(value) <- "rgio_raster"

  files <- file.path(tempdir(), paste0("rgio_band_", seq_along(value), ".tif"))
  on.exit(unlink(files, recursive = FALSE, force = TRUE), add = TRUE)

  rg_write(value, files, datatype = "Float32")

  bbox <- compute_bbox(gt, width, height)
  for (i in seq_along(files)) {
    raster <- rg_read(files[[i]], bbox, width, height, "EPSG:4326")
    expect_equal(raster[[1]], value[[i]], tolerance = 1e-7)
  }
})

test_that("rg_write() supports multiple GDAL datatypes", {
  gt <- c(0, 1, 0, 1, 0, -1)
  datatypes <- list(
    Byte = list(values = c(0, NA, 255), nodata = 255),
    UInt16 = list(values = c(0, NA, 65535), nodata = 0),
    Int16 = list(values = c(-100, NA, 100), nodata = -32768),
    UInt32 = list(values = c(0, NA, 1000), nodata = 0),
    Int32 = list(values = c(-1000, NA, 1000), nodata = -9999),
    Float32 = list(values = c(-1.5, NA, 2.5), nodata = -9999),
    Float64 = list(values = c(-1.5, NA, 2.5), nodata = NA_real_)
  )

  temp_files <- character()
  on.exit(unlink(temp_files), add = TRUE)

  for (dtype in names(datatypes)) {
    spec <- datatypes[[dtype]]
    file <- tempfile(fileext = ".tif")
    temp_files <- c(temp_files, file)
    rg_write(
      spec$values,
      file,
      gt = gt,
      width = 3L,
      height = 1L,
      crs = "EPSG:4326",
      datatype = dtype,
      nodata = spec$nodata
    )
    info <- rg_info(file)
    expect_equal(info$dtype, dtype)
  }
})

test_that("rg_write() enforces byte range limits", {
  gt <- c(0, 1, 0, 1, 0, -1)
  file <- tempfile(fileext = ".tif")
  on.exit(unlink(file), add = TRUE)

  expect_error(
    rg_write(
      300,
      file,
      gt = gt,
      width = 1L,
      height = 1L,
      crs = "EPSG:4326",
      datatype = "Byte",
      nodata = 255
    ),
    "Raster value .* out of range"
  )

  expect_error(
    rg_write(
      NA_real_,
      file,
      gt = gt,
      width = 1L,
      height = 1L,
      crs = "EPSG:4326",
      datatype = "Byte",
      nodata = 300
    ),
    "nodata value .* out of range"
  )
})
