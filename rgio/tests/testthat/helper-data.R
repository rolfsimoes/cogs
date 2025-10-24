test_data_path <- function(...) {
  base <- system.file("testdata", package = "rgio")
  if (base == "") {
    base <- testthat::test_path("..", "..", "inst", "testdata")
  }
  normalizePath(file.path(base, ...), mustWork = TRUE)
}

copy_test_data <- function(name) {
  src <- test_data_path(name)
  ext <- tools::file_ext(src)
  suffix <- if (nzchar(ext)) paste0(".", ext) else ""
  tmp <- tempfile(fileext = suffix)
  file.copy(src, tmp, overwrite = TRUE)
  tmp
}
