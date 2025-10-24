test_that("new_githubrelease creates a missing release", {
  created <- NULL
  cleared <- FALSE

  testthat::local_mocked_bindings(
    pb_releases_safe = function(repo) {
      data.frame(tag_name = "v0", stringsAsFactors = FALSE)
    },
    pb_new_release_safe = function(repo, tag, body) {
      created <<- list(repo = repo, tag = tag, body = body)
    },
    .env = asNamespace("ghcog")
  )

  testthat::local_mocked_bindings(
    refresh_piggyback_cache = function() {
      cleared <<- TRUE
      invisible(NULL)
    },
    .env = asNamespace("ghcog")
  )

  new_githubrelease("owner/repo", "v1", "notes")

  expect_equal(created$repo, "owner/repo")
  expect_equal(created$tag, "v1")
  expect_equal(created$body, "notes")
  expect_true(cleared)
})

test_that("new_githubrelease is a no-op when release exists", {
  created <- FALSE

  testthat::local_mocked_bindings(
    pb_releases_safe = function(repo) {
      data.frame(tag_name = c("v0", "v1"), stringsAsFactors = FALSE)
    },
    pb_new_release_safe = function(...) {
      created <<- TRUE
    },
    .env = asNamespace("ghcog")
  )

  new_githubrelease("owner/repo", "v1", "notes")
  expect_false(created)
})

test_that("upload_githubassets skips existing assets unless overwritten", {
  existing_file <- tempfile(fileext = ".tif")
  new_file <- tempfile(fileext = ".tif")
  on.exit(unlink(c(existing_file, new_file)), add = TRUE)
  file.create(existing_file)
  file.create(new_file)

  uploaded_assets <- character()

  testthat::local_mocked_bindings(
    pb_releases_safe = function(repo) {
      data.frame(tag_name = "v1", stringsAsFactors = FALSE)
    },
    pb_list_safe = function(repo, tag) {
      data.frame(
        file_name = c(basename(existing_file)),
        stringsAsFactors = FALSE
      )
    },
    pb_upload_safe = function(file, repo, tag, overwrite) {
      uploaded_assets <<- c(uploaded_assets, basename(file))
    },
    .env = asNamespace("ghcog")
  )

  testthat::local_mocked_bindings(
    refresh_piggyback_cache = function() invisible(NULL),
    .env = asNamespace("ghcog")
  )

  uploaded <- upload_githubassets(
    files = c(existing_file, new_file),
    repo = "owner/repo",
    tag = "v1",
    overwrite = FALSE
  )

  expect_equal(uploaded_assets, basename(new_file))
  expect_equal(uploaded, normalizePath(new_file, winslash = "/", mustWork = TRUE))

  uploaded_assets <- character()
  upload_githubassets(
    files = c(existing_file),
    repo = "owner/repo",
    tag = "v1",
    overwrite = TRUE
  )
  expect_equal(uploaded_assets, basename(existing_file))
})
