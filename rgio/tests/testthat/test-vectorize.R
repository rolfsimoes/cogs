test_that("rg_vectorize() validates input parameters", {
  expect_error(
    rg_vectorize(c("in1.tif", "in2.tif"), "out.gpkg"),
    "'src' must be a single character string"
  )

  expect_error(
    rg_vectorize("input.tif", c("out1.gpkg", "out2.gpkg")),
    "'dst' must be a single character string"
  )

  expect_error(
    rg_vectorize("input.tif", "out.gpkg", format = 123),
    "'format' must be a single character string"
  )

  expect_error(
    rg_vectorize("input.tif", "out.gpkg", band = 0),
    "'band' must be a positive integer"
  )

  expect_error(
    rg_vectorize("input.tif", "out.gpkg", field = c("a", "b")),
    "'field' must be a single character string"
  )

  expect_error(
    rg_vectorize("input.tif", "out.gpkg", connectedness = 7),
    "'connectedness' must be either 4 or 8"
  )

  expect_error(
    rg_vectorize("input.tif", "out.gpkg", mask = c("mask1.tif", "mask2.tif")),
    "'mask' must be NULL or a single character string"
  )
})

test_that("rg_vectorize() converts raster classes to polygons", {
  dst <- tempfile(fileext = ".gpkg")
  on.exit(unlink(dst), add = TRUE)

  expect_invisible(rg_vectorize(test_data_path("grid_class.tif"), dst, format = "GPKG"))
  expect_true(file.exists(dst))
  expect_gt(file.info(dst)$size, 0)
})

test_that("rg_vectorize() honors mask raster and 4-connectedness", {
  dst <- tempfile(fileext = ".gpkg")
  mask <- tempfile(fileext = ".tif")
  on.exit(unlink(c(dst, mask)), add = TRUE)

  mask_values <- matrix(
    c(1, 1, 1,
      0, 0, 1,
      1, 1, 1),
    nrow = 3,
    byrow = TRUE
  )

  rg_write(mask_values, mask,
           gt = c(0, 1, 0, 3, 0, -1),
           crs = "EPSG:4326",
           datatype = "Byte",
           nodata = 0)

  expect_invisible(
    rg_vectorize(
      test_data_path("grid_class.tif"),
      dst,
      format = "GPKG",
      connectedness = 4L,
      mask = mask
    )
  )
  expect_true(file.exists(dst))
  expect_gt(file.info(dst)$size, 0)
})

test_that("rg_vectorize() fails when mask cannot be opened", {
  dst <- tempfile(fileext = ".gpkg")
  missing_mask <- tempfile(fileext = ".tif")
  on.exit(unlink(dst), add = TRUE)

  expect_error(
    rg_vectorize(
      test_data_path("grid_class.tif"),
      dst,
      format = "GPKG",
      mask = missing_mask
    ),
    "Failed to open mask dataset",
    fixed = TRUE
  )
})

test_that("rg_vectorize() errors when driver is unavailable", {
  dst <- tempfile(fileext = ".gpkg")
  on.exit(unlink(dst), add = TRUE)

  expect_error(
    rg_vectorize(
      test_data_path("grid_class.tif"),
      dst,
      format = "BOGUS"
    ),
    "Vector driver not available",
    fixed = TRUE
  )
})

test_that("rg_vectorize() forwards creation options", {
  dst <- tempfile(fileext = ".gpkg")
  on.exit(unlink(dst), add = TRUE)

  expect_invisible(
    rg_vectorize(
      test_data_path("grid_class.tif"),
      dst,
      format = "GPKG",
      co = c("SPATIAL_INDEX=NO")
    )
  )
  expect_true(file.exists(dst))
})
