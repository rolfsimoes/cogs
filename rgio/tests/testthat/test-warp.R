test_that("rg_warp() validates input parameters", {
  # Test that rg_warp() checks for valid inputs
  
  expect_error(
    rg_warp(character(0), "output.tif"),
    "'src' must be a non-empty character vector"
  )
  
  expect_error(
    rg_warp("input.tif", c("out1.tif", "out2.tif")),
    "'dst' must be a single character string"
  )
  
  expect_error(
    rg_warp("input.tif", "output.tif", tr = c(1)),
    "'tr' must be a numeric vector of length 2"
  )
  
  expect_error(
    rg_warp("input.tif", "output.tif", crs = c("EPSG:4326", "EPSG:3857")),
    "'crs' must be a single character string"
  )
  
  expect_error(
    rg_warp("input.tif", "output.tif", resample = "invalid"),
    "Unsupported resampling method"
  )
  
  expect_error(
    rg_warp("input.tif", "output.tif", dstnodata = "NA"),
    "'dstnodata' must be a single numeric value (NA allowed)",
    fixed = TRUE
  )
  
  expect_error(
    rg_warp("input.tif", "output.tif", format = c("GTiff", "COG")),
    "'format' must be a single character string"
  )
  
  expect_error(
    rg_warp("input.tif", "output.tif", threads = -1),
    "'threads' must be >= 0"
  )
  
  expect_error(
    rg_warp("input.tif", "output.tif", overwrite = "yes"),
    "'overwrite' must be a single logical value"
  )
})

test_that("rg_warp() writes warped raster", {
  dst <- tempfile(fileext = ".tif")
  on.exit(unlink(dst), add = TRUE)

  expect_invisible(
    rg_warp(
      test_data_path("grid_base.tif"),
      dst,
      tr = c(1, 1),
      crs = "EPSG:4326",
      resample = "bilinear",
      dstnodata = -999,
      wo = c("NUM_THREADS=2"),
      co = c("COMPRESS=LZW"),
      overwrite = TRUE
    )
  )

  expect_true(file.exists(dst))

  info <- rg_info(dst)
  expect_equal(info$width, 3L)
  expect_equal(info$height, 3L)
  expect_equal(info$nodata, -999)
})
