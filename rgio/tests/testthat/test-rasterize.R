test_that("rg_rasterize() validates input parameters", {
  # Test that rg_rasterize() checks for valid inputs
  
  expect_error(
    rg_rasterize(character(0), "outdir"),
    "'files' must be a non-empty character vector"
  )
  
  expect_error(
    rg_rasterize("file.shp", c("dir1", "dir2")),
    "'outdir' must be a single character string"
  )
  
  expect_error(
    rg_rasterize("file.shp", "outdir", field = c("a", "b")),
    "'field' must be a single character string"
  )
  
  expect_error(
    rg_rasterize("file.shp", "outdir", res = c(1)),
    "'res' must be a numeric vector of length 2"
  )
  
  expect_error(
    rg_rasterize("file.shp", "outdir", crs = c("EPSG:4326", "EPSG:3857")),
    "'crs' must be a single character string"
  )
  
  expect_error(
    rg_rasterize("file.shp", "outdir", nodata = "NA"),
    "'nodata' must be numeric or integer"
  )
  
  expect_error(
    rg_rasterize("file.shp", "outdir", threads = "auto"),
    "'threads' must be a single, non-missing value"
  )

  expect_error(
    rg_rasterize("file.shp", "outdir", threads = -1),
    "'threads' must be >= 0"
  )
})

test_that("rg_rasterize() rasterizes GeoJSON polygons", {
  outdir <- tempfile("rg_rasterize_")
  dir.create(outdir)
  on.exit(unlink(outdir, recursive = TRUE), add = TRUE)

  outputs <- rg_rasterize(
    test_data_path("square.geojson"),
    outdir,
    field = "class",
    res = c(1, 1),
    crs = "EPSG:4326",
    nodata = 0L,
    threads = 2L
  )

  expect_length(outputs, 1L)
  expect_true(file.exists(outputs[[1]]))

  data <- rg_read(outputs[[1]], c(0, 0, 3, 3), width = 3L, height = 3L, crs = "EPSG:4326")
  expect_true(all(data[[1]] == 5))
})

test_that("rg_rasterize() burns constant when attribute missing", {
  outdir <- tempfile("rg_rasterize_missing_")
  dir.create(outdir)
  on.exit(unlink(outdir, recursive = TRUE), add = TRUE)

  outputs <- rg_rasterize(
    test_data_path("square.geojson"),
    outdir,
    field = "missing",
    res = c(1, 1),
    crs = "EPSG:4326",
    nodata = 0L
  )

  data <- rg_read(outputs[[1]], c(0, 0, 3, 3), width = 3L, height = 3L, crs = "EPSG:4326")
  expect_true(all(data[[1]] == 1))
})

test_that("rg_rasterize() detects invalid raster dimensions", {
  outdir <- tempfile("rg_rasterize_invalid_")
  dir.create(outdir)
  on.exit(unlink(outdir, recursive = TRUE), add = TRUE)

  expect_error(
    rg_rasterize(
      test_data_path("square.geojson"),
      outdir,
      field = "class",
      res = c(100, 100),
      crs = "EPSG:4326",
      nodata = 0L
    ),
    "Invalid raster dimensions",
    fixed = TRUE
  )
})

test_that("rg_rasterize() errors when vector source missing", {
  outdir <- tempfile("rg_rasterize_missing_src_")
  dir.create(outdir)
  on.exit(unlink(outdir, recursive = TRUE), add = TRUE)

  missing <- file.path(tempdir(), "missing.geojson")
  expect_error(
    rg_rasterize(
      missing,
      outdir,
      field = "class",
      res = c(1, 1),
      crs = "EPSG:4326",
      nodata = 0L
    ),
    "Failed to open vector file",
    fixed = TRUE
  )
})
