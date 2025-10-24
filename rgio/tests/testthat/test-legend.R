test_that("rg_legend() validates input parameters", {
  # Test that rg_legend() checks for valid inputs
  
  expect_error(
    rg_legend(c("file1.tif", "file2.tif"), c(1, 2), matrix(c(255, 0, 0, 255), ncol = 4)),
    "'file' must be a single character string"
  )
  
  expect_error(
    rg_legend("file.tif", "one", matrix(c(255, 0, 0, 255), ncol = 4)),
    "'values' must be numeric or integer vector"
  )
  
  expect_error(
    rg_legend("file.tif", c(1, 2), c(255, 0, 255, 255)),
    "'colors_rgba' must be a matrix or data frame with 4 columns"
  )
  
  expect_error(
    rg_legend("file.tif", c(1, 2), matrix(c(255, 0, 0), ncol = 3)),
    "'colors_rgba' must be a matrix or data frame with 4 columns"
  )
  
  expect_error(
    rg_legend("file.tif", c(1, 2, 3), matrix(c(255, 0, 0, 255, 0, 255, 0, 255), ncol = 4, byrow = TRUE)),
    "Number of rows in 'colors_rgba' must match length of 'values'"
  )
  
  expect_error(
    rg_legend("file.tif", c(1, 2), matrix(c(255, 0, 0, 255, 0, 255, 0, 255), ncol = 4, byrow = TRUE), labels = 123),
    "'labels' must be a character vector or NULL"
  )
  
  expect_error(
    rg_legend("file.tif", c(1, 2), matrix(c(255, 0, 0, 255, 0, 255, 0, 255), ncol = 4, byrow = TRUE), labels = c("a", "b", "c")),
    "Length of 'labels' must match length of 'values'"
  )
})

test_that("rg_legend() writes color table and labels", {
  tif <- tempfile(fileext = ".tif")
  on.exit(unlink(tif), add = TRUE)

  # Create a simple raster with class values 0 and 1
  gt <- c(0, 1, 0, 2, 0, -1)
  values <- matrix(c(0, 1, 0, 1), nrow = 2, byrow = TRUE)
  rg_write(values, tif, gt = gt, crs = "EPSG:4326", datatype = "Byte")

  palette_matrix <- matrix(
    c(255, 0, 0, 255,
      0, 255, 0, 255),
    ncol = 4,
    byrow = TRUE
  )
  class_labels <- c("background", "class1")

  expect_invisible(rg_legend(tif, 0:1, palette_matrix, class_labels))

  pal_info <- rg_palette(tif, 0:1)
  expected_colors <- matrix(
    as.integer(c(255, 0, 0, 255,
                 0, 255, 0, 255)),
    ncol = 4,
    byrow = TRUE
  )

  expect_identical(pal_info$colors, expected_colors)
  expect_identical(pal_info$labels, class_labels)
})

test_that("rg_palette() coerces numeric indices", {
  tif <- copy_test_data("grid_class.tif")
  on.exit(unlink(tif), add = TRUE)

  colors <- matrix(
    c(0, 0, 0, 255,
      255, 255, 255, 255,
      128, 0, 128, 255,
      0, 128, 0, 255,
      0, 0, 255, 255),
    ncol = 4,
    byrow = TRUE
  )
  rg_legend(tif, 0:4, colors)

  pal <- rg_palette(tif, as.numeric(0:2))
  expected <- colors[1:3, , drop = FALSE]
  storage.mode(expected) <- "integer"
  expect_identical(pal$colors, expected)
})

test_that("rg_legend() accepts data frame colors", {
  tif <- tempfile(fileext = ".tif")
  on.exit(unlink(tif), add = TRUE)

  gt <- c(0, 1, 0, 2, 0, -1)
  values <- matrix(c(0, 1, 0, 1), nrow = 2, byrow = TRUE)
  rg_write(values, tif, gt = gt, crs = "EPSG:4326", datatype = "Byte")

  colors_df <- data.frame(
    R = c(255, 0),
    G = c(0, 255),
    B = c(0, 0),
    A = c(255, 255)
  )
  class_labels <- c("background", "class1")

  expect_invisible(rg_legend(tif, 0:1, colors_df, class_labels))

  pal_info <- rg_palette(tif, 0:1)
  expected_colors <- matrix(
    as.integer(c(255, 0, 0, 255,
                 0, 255, 0, 255)),
    ncol = 4,
    byrow = TRUE
  )
  
  expect_identical(pal_info$colors, expected_colors)
  expect_identical(pal_info$labels, class_labels)
})
