test_that("rg_read() validates input parameters", {
  # Test that rg_read() checks for valid inputs
  
  expect_error(
    rg_read(character(0), c(0, 0, 1, 1), 100, 100, "EPSG:4326"),
    "'src' must be a non-empty character vector"
  )
  
  expect_error(
    rg_read("input.tif", c(0, 0, 1), 100, 100, "EPSG:4326"),
    "'bbox' must be a numeric vector of length 4"
  )
  
  expect_error(
    rg_read("input.tif", c(0, 0, 1, 1), "100", 100, "EPSG:4326"),
    "'width' must be numeric or integer"
  )
  
  expect_error(
    rg_read("input.tif", c(0, 0, 1, 1), 100, "100", "EPSG:4326"),
    "'height' must be numeric or integer"
  )
  
  expect_error(
    rg_read("input.tif", c(0, 0, 1, 1), 100, 100, c("EPSG:4326", "EPSG:3857")),
    "'crs' must be a single character string"
  )
  
  expect_error(
    rg_read("input.tif", c(0, 0, 1, 1), 100, 100, "EPSG:4326", resample = "invalid"),
    "Unsupported resampling method"
  )
  
  expect_error(
    rg_read("input.tif", c(0, 0, 1, 1), 100, 100, "EPSG:4326", nodata = c(NA, NA)),
    "'nodata' must be a single numeric value"
  )
  
  expect_error(
    rg_read("input.tif", c(0, 0, 1, 1), 100, 100, "EPSG:4326", threads = "auto"),
    "'threads' must be a single, non-missing value"
  )

  expect_error(
    rg_read("input.tif", c(0, 0, 1, 1), 100, 100, "EPSG:4326", threads = -1),
    "'threads' must be >= 0"
  )
})

test_that("rg_read() reads raster values into grid", {
  src <- test_data_path("grid_base.tif")
  data <- rg_read(src, c(0, 0, 3, 3), width = 3L, height = 3L, crs = "EPSG:4326")
  expect_s3_class(data, "data.frame")
  expect_equal(nrow(data), 9L)
  expect_identical(data[[1]], as.numeric(1:9))
  expect_equal(attr(data, "width"), 3L)
  expect_equal(attr(data, "height"), 3L)
  expect_equal(attr(data, "crs"), "EPSG:4326")
})

test_that("rg_read() stacks multiple rasters", {
  sources <- c(
    test_data_path("grid_base.tif"),
    test_data_path("grid_class.tif")
  )
  data <- rg_read(sources, c(0, 0, 3, 3), width = 3L, height = 3L, crs = "EPSG:4326")
  expect_equal(ncol(data), 2L)
  expect_identical(data$b1, as.numeric(1:9))
  expect_identical(data$b2, as.numeric(c(0, 1, 1, 2, 2, 3, 3, 3, 4)))
})

test_that("rg_read() surfaces GDAL errors for missing files", {
  missing <- file.path(tempdir(), "missing-file.tif")
  expect_error(
    rg_read(missing, c(0, 0, 1, 1), width = 1L, height = 1L, crs = "EPSG:4326"),
    "Failed to open source file",
    fixed = TRUE
  )
})

test_that("rg_read() accepts warp options and thread hints", {
  data <- rg_read(
    test_data_path("grid_base.tif"),
    c(0, 0, 3, 3),
    width = 3L,
    height = 3L,
    crs = "EPSG:4326",
    threads = 2L,
    wo = c("NUM_THREADS=2")
  )
  expect_equal(attr(data, "width"), 3L)
  expect_equal(attr(data, "height"), 3L)
})

test_that("rg_read() supports alternate resampling algorithms", {
  methods <- c(
    "bilinear", "cubic", "cubicspline", "lanczos",
    "average", "mode", "min", "max",
    "med", "sum", "rms", "q1", "q3"
  )
  for (method in methods) {
    data <- rg_read(
      test_data_path("grid_base.tif"),
      c(0, 0, 3, 3),
      width = 3L,
      height = 3L,
      crs = "EPSG:4326",
      resample = method
    )
    expect_equal(nrow(data), 9L)
  }
})
