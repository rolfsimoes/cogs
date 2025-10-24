test_that("rg_overviews() validates inputs", {
  expect_error(
    rg_overviews(c("a.tif", "b.tif")),
    "'path' must be a single character string"
  )

  expect_error(
    rg_overviews("a.tif", levels = c(1, 2)),
    "'levels' must be numeric values greater than 1"
  )

  expect_error(
    rg_overviews("a.tif", resample = "invalid"),
    "Unsupported resampling method"
  )

  expect_error(
    rg_overviews("a.tif", external = c(TRUE, FALSE)),
    "'external' must be a single logical value"
  )

  expect_error(
    rg_overviews("a.tif", threads = c(1, 2)),
    "'threads' must be a single, non-missing value"
  )
})

test_that("rg_overviews() builds external pyramids", {
  tif <- copy_test_data("grid_large.tif")
  ovr <- paste0(tif, ".ovr")
  on.exit(unlink(c(tif, ovr)), add = TRUE)

  expect_invisible(rg_overviews(tif, levels = c(2), external = TRUE))
  info_lines <- system2("gdalinfo", tif, stdout = TRUE)
  has_overviews <- any(grepl("Overviews:", info_lines, fixed = TRUE))
  expect_true(has_overviews)
})

test_that("rg_overviews() selects defaults when levels omitted", {
  tif <- copy_test_data("grid_large.tif")
  on.exit(unlink(tif), add = TRUE)

  expect_invisible(rg_overviews(tif))
  info_lines <- system2("gdalinfo", tif, stdout = TRUE)
  expect_true(any(grepl("Overviews:", info_lines, fixed = TRUE)))
})
