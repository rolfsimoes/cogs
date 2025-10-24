test_that("rg_vrt_build() validates input parameters", {
  expect_error(
    rg_vrt_build(character(0), c(0, 0, 1, 1), 100, 100, "EPSG:4326"),
    "'src' must be a non-empty character vector"
  )

  expect_error(
    rg_vrt_build("input.tif", c(0, 0, 1), 100, 100, "EPSG:4326"),
    "'bbox' must be a numeric vector of length 4"
  )

  expect_error(
    rg_vrt_build("input.tif", c(0, 0, 1, 1), "100", 100, "EPSG:4326"),
    "'width' must be numeric or integer"
  )

  expect_error(
    rg_vrt_build("input.tif", c(0, 0, 1, 1), 100, "100", "EPSG:4326"),
    "'height' must be numeric or integer"
  )

  expect_error(
    rg_vrt_build("input.tif", c(0, 0, 1, 1), 100, 100, c("EPSG:4326", "EPSG:3857")),
    "'crs' must be a single character string"
  )

  expect_error(
    rg_vrt_build("input.tif", c(0, 0, 1, 1), 100, 100, "EPSG:4326", options = "option"),
    "'options' must be a list"
  )

  expect_error(
    rg_vrt_build("input.tif", c(0, 0, 1, 1), 100, 100, "EPSG:4326", palette = 1),
    "Unsupported palette input"
  )
})

test_that("rg_vrt_build() composes in-memory VRT with palette and legend", {
  src <- test_data_path("grid_class.tif")
  bbox <- c(0, 0, 3, 3)
  palette_df <- data.frame(
    value = 0:4,
    r = c(0L, 63L, 127L, 191L, 255L),
    g = c(0L, 32L, 64L, 96L, 128L),
    b = c(0L, 0L, 0L, 0L, 0L),
    a = rep(255L, 5)
  )
  categories <- paste0("class", 0:4)

  vrt_vs <- rg_vrt_build(
    src,
    bbox,
    width = 3L,
    height = 3L,
    crs = "EPSG:4326",
    palette = palette_df,
    categories = categories
  )

  expect_true(startsWith(vrt_vs, "/vsimem/"))

  vrt_disk <- tempfile(fileext = ".vrt")
  on.exit(unlink(vrt_disk), add = TRUE)

  expect_invisible(rg_translate(vrt_vs, vrt_disk, format = "VRT"))

  pal <- rg_vrt_palette(vrt_disk)
  expect_equal(pal$values, 0:4)
  expected_colors <- unname(as.matrix(palette_df[, c("r", "g", "b", "a")]))
  storage.mode(expected_colors) <- "integer"
  expect_identical(pal$colors, expected_colors)

  legend <- rg_vrt_legend(vrt_disk)
  expect_identical(legend[1:5], categories)
})

test_that("rg_vrt_palette() validation works", {
  expect_error(
    rg_vrt_palette(c("file.vrt", "other.vrt")),
    "'file' must be a single character string"
  )

  expect_error(
    rg_vrt_palette("file.vrt", palette = list(values = 1)),
    "List palette inputs must contain 'values' and 'colors'"
  )
})

test_that("rg_vrt_legend() validation works", {
  expect_error(
    rg_vrt_legend(c("file.vrt", "other.vrt")),
    "'file' must be a single character string"
  )

  expect_error(
    rg_vrt_legend("file.vrt", values = 1:2),
    "Both 'values' and 'labels' must be supplied"
  )

  expect_error(
    rg_vrt_legend("file.vrt", values = 1:2, labels = "a"),
    "'values' and 'labels' must have the same length"
  )
})

test_that("rg_vrt_palette() and rg_vrt_legend() update VRT metadata", {
  src <- test_data_path("grid_base.tif")
  bbox <- c(0, 0, 3, 3)
  vrt_vs <- rg_vrt_build(src, bbox, width = 3L, height = 3L, crs = "EPSG:4326")

  vrt_disk <- tempfile(fileext = ".vrt")
  on.exit(unlink(vrt_disk), add = TRUE)

  expect_invisible(rg_translate(vrt_vs, vrt_disk, format = "VRT"))

  new_palette <- list(
    values = 0:1,
    colors = matrix(
      as.integer(c(0, 0, 0, 255,
                   255, 255, 255, 255)),
      ncol = 4,
      byrow = TRUE
    )
  )

  expect_invisible(rg_vrt_palette(vrt_disk, palette = new_palette))
  pal <- rg_vrt_palette(vrt_disk)
  expect_identical(pal$colors[1:2, ], new_palette$colors)

  expect_invisible(rg_vrt_legend(vrt_disk, values = 0:1, labels = c("zero", "one")))
  legend <- rg_vrt_legend(vrt_disk)
  expect_identical(legend[1:2], c("zero", "one"))
})

test_that("rg_vrt_palette() returns empty structures when palette absent", {
  src <- test_data_path("grid_base.tif")
  bbox <- c(0, 0, 3, 3)
  vrt_vs <- rg_vrt_build(src, bbox, width = 3L, height = 3L, crs = "EPSG:4326")

  vrt_disk <- tempfile(fileext = ".vrt")
  on.exit(unlink(vrt_disk), add = TRUE)

  expect_invisible(rg_translate(vrt_vs, vrt_disk, format = "VRT"))

  pal <- rg_vrt_palette(vrt_disk)
  expect_identical(pal$values, integer())
  expect_identical(dim(pal$colors), c(0L, 4L))
})
