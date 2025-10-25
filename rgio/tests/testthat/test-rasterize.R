test_that("rg_rasterize() validates input parameters", {
  expect_error(
    rg_rasterize(character(0), "outdir"),
    "'files' must be a non-empty character vector"
  )

  expect_error(
    rg_rasterize("file.shp", c("dir1", "dir2")),
    "'outdir' must be a single character string"
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
    rg_rasterize("file.shp", "outdir", dtype = c("Byte", "UInt16")),
    "'dtype' must be a single character string"
  )

  expect_error(
    rg_rasterize("file.shp", "outdir", format = c("GTiff", "COG")),
    "'format' must be a single character string"
  )

  expect_error(
    rg_rasterize("file.shp", "outdir", threads = "auto"),
    "'threads' must be a single, non-missing value"
  )
})

test_that("rg_rasterize() rasterizes GeoJSON polygons", {
  outdir <- tempfile("rg_rasterize_")
  dir.create(outdir)
  on.exit(unlink(outdir, recursive = TRUE), add = TRUE)

  outputs <- rg_rasterize(
    files   = test_data_path("square.geojson"),
    outdir  = outdir,
    field   = "class", # use field instead of ro
    res     = c(1, 1),
    crs     = "EPSG:4326",
    nodata  = 0L,
    dtype   = "UInt16",
    format  = "GTiff",
    threads = 2L
  )

  expect_length(outputs, 1L)
  expect_true(file.exists(outputs[[1]]))

  data <- rg_read(
    outputs[[1]],
    bbox = c(0, 0, 3, 3),
    width = 3L,
    height = 3L,
    crs = "EPSG:4326"
  )

  expect_true(all(data[[1]] == 5))
})

test_that("rg_rasterize() burns constant when attribute missing", {
  outdir <- tempfile("rg_rasterize_missing_")
  dir.create(outdir)
  on.exit(unlink(outdir, recursive = TRUE), add = TRUE)

  outputs <- rg_rasterize(
    files   = test_data_path("square.geojson"),
    outdir  = outdir,
    res     = c(1, 1),
    crs     = "EPSG:4326",
    nodata  = 0L,
    dtype   = "UInt16",
    format  = "GTiff",
    # specify a non-existent attribute field
    ro      = c("ATTRIBUTE=missing"),
    # burn constant value if attribute not found
    value   = 1
  )

  data <- rg_read(outputs[[1]], bbox = c(0, 0, 3, 3), width = 3L, height = 3L, crs = "EPSG:4326")
  expect_true(all(data[[1]] == 1))
})

test_that("rg_rasterize() creates extremely small rasters for coarse resolution", {
  outdir <- tempfile("rg_rasterize_small_")
  dir.create(outdir)
  on.exit(unlink(outdir, recursive = TRUE), add = TRUE)

  outputs <- rg_rasterize(
    files   = test_data_path("square.geojson"),
    outdir  = outdir,
    field   = "class",
    res     = c(1e9, 1e9),
    crs     = "EPSG:4326",
    nodata  = 0L,
    dtype   = "Int32",
    format  = "GTiff"
  )

  expect_true(file.exists(outputs[[1]]))

  info <- rg_info(outputs[[1]])
  expect_true(info$width <= 1 && info$height <= 1)
})

test_that("rg_rasterize() errors when vector source missing", {
  outdir <- tempfile("rg_rasterize_missing_src_")
  dir.create(outdir)
  on.exit(unlink(outdir, recursive = TRUE), add = TRUE)

  missing <- file.path(tempdir(), "missing.geojson")

  expect_error(
    rg_rasterize(
      files   = missing,
      outdir  = outdir,
      res     = c(1, 1),
      crs     = "EPSG:4326",
      nodata  = 0L,
      dtype   = "UInt16",
      format  = "GTiff",
      ro      = c("ATTRIBUTE=class")
    ),
    "Failed to open vector file",
    fixed = TRUE
  )
})

test_that("rg_rasterize() supports multiple output formats and data types", {
  outdir <- tempfile("rg_rasterize_formats_")
  dir.create(outdir)
  on.exit(unlink(outdir, recursive = TRUE), add = TRUE)

  formats <- c("GTiff")
  dtypes <- c("Byte", "Float32")

  for (fmt in formats) {
    for (dt in dtypes) {
      outputs <- rg_rasterize(
        files   = test_data_path("square.geojson"),
        outdir  = outdir,
        value   = 10,
        res     = c(1, 1),
        crs     = "EPSG:4326",
        nodata  = 0L,
        dtype   = dt,
        format  = fmt,
        threads = 1L
      )
      expect_true(file.exists(outputs[[1]]))
      meta <- rg_info(outputs[[1]])
      expect_match(meta$driver, fmt)
      expect_equal(meta$datatype, dt)
    }
  }
})

test_that("rg_rasterize() applies GDAL creation options", {
  outdir <- tempfile("rg_rasterize_co_")
  dir.create(outdir)
  on.exit(unlink(outdir, recursive = TRUE), add = TRUE)

  outputs <- rg_rasterize(
    files   = test_data_path("square.geojson"),
    outdir  = outdir,
    res     = c(1, 1),
    crs     = "EPSG:4326",
    dtype   = "UInt16",
    format  = "GTiff",
    co      = c("COMPRESS=DEFLATE", "TILED=YES")
  )

  info <- system(paste("gdalinfo -json", shQuote(outputs[[1]])), intern = TRUE)
  txt <- paste(info, collapse = "\n")
  expect_match(txt, "DEFLATE")
  expect_match(txt, "TILED")
})

test_that("rg_rasterize() produces identical results with different thread counts", {
  outdir1 <- tempfile("rg_rasterize_t1_")
  outdir2 <- tempfile("rg_rasterize_t2_")
  dir.create(outdir1)
  dir.create(outdir2)
  on.exit(
    {
      unlink(outdir1, recursive = TRUE)
      unlink(outdir2, recursive = TRUE)
    },
    add = TRUE
  )

  out1 <- rg_rasterize(test_data_path("square.geojson"), outdir1,
    res = c(1, 1), threads = 1L
  )
  out2 <- rg_rasterize(test_data_path("square.geojson"), outdir2,
    res = c(1, 1), threads = 4L
  )

  a <- rg_read(out1[[1]], c(0, 0, 3, 3), width = 3L, height = 3L, crs = "EPSG:4326")
  b <- rg_read(out2[[1]], c(0, 0, 3, 3), width = 3L, height = 3L, crs = "EPSG:4326")

  expect_equal(a[[1]], b[[1]])
})

test_that("rg_rasterize() correctly assigns CRS and geotransform", {
  outdir <- tempfile("rg_rasterize_crs_")
  dir.create(outdir)
  on.exit(unlink(outdir, recursive = TRUE), add = TRUE)

  out <- rg_rasterize(
    files   = test_data_path("square.geojson"),
    outdir  = outdir,
    res     = c(1, 1),
    crs     = "EPSG:4326",
    dtype   = "UInt16"
  )

  meta <- rg_info(out[[1]])
  expect_match(meta$crs, "4326")
  expect_true(all(c("origin", "pixel_size") %in% names(meta)))
})

test_that("rg_rasterize() handles empty vector layers gracefully", {
  outdir <- tempfile("rg_rasterize_empty_")
  dir.create(outdir)
  on.exit(unlink(outdir, recursive = TRUE), add = TRUE)

  empty <- test_data_path("empty.geojson") # GeoJSON with no features
  expect_error(
    rg_rasterize(empty, outdir, res = c(1, 1), crs = "EPSG:4326"),
    "Failed to get extent",
    fixed = TRUE
  )
})

test_that("rg_rasterize() integrates correctly with rg_read() and rg_warp()", {
  outdir <- tempfile("rg_pipeline_")
  dir.create(outdir)
  on.exit(unlink(outdir, recursive = TRUE), add = TRUE)

  tiff <- rg_rasterize(
    test_data_path("square.geojson"),
    outdir,
    res = c(1, 1),
    crs = "EPSG:4326"
  )[[1]]

  warped <- tempfile(fileext = ".tif")
  rg_warp(tiff, warped, crs = "EPSG:3857", res = c(10, 10))

  expect_true(file.exists(warped))
  data <- rg_read(warped, bbox = c(0, 0, 100, 100), width = 10, height = 10, crs = "EPSG:3857")
  expect_true(is.numeric(data[[1]]))
})
