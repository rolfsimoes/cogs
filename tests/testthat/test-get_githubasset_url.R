test_that("get_githubasset_url returns the signed redirect location", {
  calls <- list()

  testthat::local_mocked_bindings(
    http_head = function(url) {
      calls$head <<- url
      list(url = url)
    },
    headers = function(response) {
      list(location = "https://signed.example/file.tif?token=abc")
    },
    status_code = function(response) 302L,
    .env = asNamespace("ghcog")
  )

  signed <- get_githubasset_url(
    file = "data/tiles/scene.tif",
    repo = "owner/repo",
    tag = "v1"
  )

  expect_equal(
    calls$head,
    "https://github.com/owner/repo/releases/download/v1/scene.tif"
  )
  expect_equal(signed, "https://signed.example/file.tif?token=abc")
})

test_that("get_githubasset_url validates the response", {
  testthat::local_mocked_bindings(
    http_head = function(url) list(url = url),
    headers = function(response) list(),
    status_code = function(response) 302L,
    .env = asNamespace("ghcog")
  )

  expect_error(
    get_githubasset_url("scene.tif", repo = "owner/repo", tag = "v1"),
    "GitHub did not return a signed URL"
  )

  testthat::local_mocked_bindings(
    http_head = function(url) list(url = url),
    headers = function(response) list(location = NULL),
    status_code = function(response) 404L,
    .env = asNamespace("ghcog")
  )

  expect_error(
    get_githubasset_url("scene.tif", repo = "owner/repo", tag = "v1"),
    "GitHub returned status 404"
  )
})
