test_that("rg_info() validates input parameters", {
  expect_error(
    rg_info(c("file1.tif", "file2.tif")),
    "'path' must be a single character string"
  )

  expect_error(
    rg_info("nonexistent_file.tif"),
    "Failed to open dataset"
  )
})

test_that("rg_info() returns basic metadata for fixture raster", {
  info <- rg_info(test_data_path("grid_base.tif"))

  expect_equal(info$width, 3L)
  expect_equal(info$height, 3L)
  expect_equal(info$bands, 1L)
  expect_equal(info$datatype, "Float64")
  expect_true(is.na(info$nodata))

  expect_true(is.numeric(info$gt))
  expect_equal(length(info$gt), 6L)
  expect_false(any(is.na(info$gt)))

  expect_true(grepl("WGS 84", info$crs))
})

test_that("rg_info() returns driver and color metadata", {
  info <- rg_info(test_data_path("grid_base.tif"))

  expect_match(info$driver, "GTiff")
  expect_match(info$driver_long, "GeoTIFF")
  expect_false(info$color_table)
  expect_false(info$categories)
})
