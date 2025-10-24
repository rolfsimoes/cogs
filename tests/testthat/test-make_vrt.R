test_that("make_vrt creates VRT files for tif assets", {
  testthat::skip_if_not_installed("sf")

  urls <- character()
  gdal_calls <- list(dest = character(), source = character())

  testthat::local_mocked_bindings(
    pb_list_safe = function(repo, tag) {
      data.frame(
        file_name = c("scene_a.tif", "readme.txt"),
        stringsAsFactors = FALSE
      )
    },
    .env = asNamespace("ghcog")
  )

  testthat::local_mocked_bindings(
    get_githubasset_url = function(file, repo, tag) {
      urls <<- c(urls, file)
      paste0("https://example.com/", file)
    },
    check_sf_available = function() TRUE,
    refresh_piggyback_cache = function() invisible(NULL),
    gdal_utils_safe = function(util, source, destination, options, quiet) {
      gdal_calls$dest <<- c(gdal_calls$dest, destination)
      gdal_calls$source <<- c(gdal_calls$source, source)
      invisible(NULL)
    },
    .env = asNamespace("ghcog")
  )

  result <- make_vrt(repo = "owner/repo", tag = "v1")

  expect_equal(basename(result), "scene_a.vrt")
  expect_equal(urls, "scene_a.tif")
  expect_equal(gdal_calls$dest, "scene_a.vrt")
  expect_equal(
    gdal_calls$source,
    "/vsicurl/https://example.com/scene_a.tif"
  )
})
