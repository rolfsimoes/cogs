test_that("rg_translate() validates input parameters", {
  expect_error(
    rg_translate(c("in1.tif", "in2.tif"), "output.tif"),
    "'src' must be a single character string"
  )

  expect_error(
    rg_translate("input.tif", c("out1.tif", "out2.tif")),
    "'dst' must be a single character string"
  )

  expect_error(
    rg_translate("input.tif", "output.tif", format = 123),
    "'format' must be NULL or a single character string"
  )

  expect_error(
    rg_translate("input.tif", "output.tif", resample = "invalid"),
    "Unsupported resampling method"
  )

  expect_error(
    rg_translate("input.tif", "output.tif", nodata = c(1, 2)),
    "'nodata' must be a single numeric value"
  )

  expect_error(
    rg_translate("input.tif", "output.tif", options = list("-projwin")),
    "'options' must be a character vector"
  )

  expect_error(
    rg_translate("input.tif", "output.tif", threads = c(1, 2)),
    "'threads' must be a single, non-missing value"
  )
})

test_that("rg_translate() creates new raster with options", {
  src <- copy_test_data("grid_base.tif")
  dst <- tempfile(fileext = ".tif")
  on.exit(unlink(c(src, dst)), add = TRUE)

  expect_invisible(rg_translate(src, dst, nodata = -999, co = c("COMPRESS=LZW")))
  expect_true(file.exists(dst))

  info <- rg_info(dst)
  expect_equal(info$width, 3L)
  expect_equal(info$height, 3L)
  expect_equal(info$nodata, -999)
})

test_that("rg_translate() applies resampling and GDAL options", {
  src <- copy_test_data("grid_base.tif")
  dst <- tempfile(fileext = ".tif")
  on.exit(unlink(c(src, dst)), add = TRUE)

  expect_invisible(
    rg_translate(
      src,
      dst,
      resample = "bilinear",
      options = c("-outsize", "50%", "50%")
    )
  )

  info <- rg_info(dst)
  expect_equal(info$width, 1L)
  expect_equal(info$height, 1L)
})
