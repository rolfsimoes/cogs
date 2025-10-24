# Internal helpers ---------------------------------------------------------

get_default_repo <- function() {
  repo <- getOption("ghcog.repo")
  if (!is.null(repo) && nzchar(repo)) {
    return(repo)
  }

  repo <- Sys.getenv("GHCOG_REPO", unset = "")
  if (nzchar(repo)) {
    return(repo)
  }

  stop(
    "Supply `repo` explicitly or set `options(ghcog.repo = 'owner/name')` ",
    "or `Sys.setenv(GHCOG_REPO = 'owner/name')`.",
    call. = FALSE
  )
}

get_default_tag <- function() {
  tag <- getOption("ghcog.tag")
  if (!is.null(tag) && nzchar(tag)) {
    return(tag)
  }

  tag <- Sys.getenv("GHCOG_TAG", unset = "")
  if (nzchar(tag)) {
    return(tag)
  }

  stop(
    "Supply `tag` explicitly or set `options(ghcog.tag = 'release-tag')` ",
    "or `Sys.setenv(GHCOG_TAG = 'release-tag')`.",
    call. = FALSE
  )
}

refresh_piggyback_cache <- function() {
  piggyback::.pb_cache_clear()
  invisible(NULL)
}

pb_releases_safe <- function(repo) {
  piggyback::pb_releases(repo = repo)
}

pb_new_release_safe <- function(repo, tag, body) {
  piggyback::pb_new_release(repo = repo, tag = tag, body = body)
}

pb_list_safe <- function(repo, tag) {
  piggyback::pb_list(repo = repo, tag = tag)
}

pb_upload_safe <- function(file, repo, tag, overwrite) {
  piggyback::pb_upload(
    file = file,
    repo = repo,
    tag = tag,
    overwrite = overwrite
  )
}

gdal_utils_safe <- function(util,
                            source,
                            destination,
                            options,
                            quiet = TRUE) {
  sf::gdal_utils(
    util = util,
    source = source,
    destination = destination,
    options = options,
    quiet = quiet
  )
}

normalize_repo <- function(repo) {
  if (!is.character(repo) || length(repo) != 1 || !grepl(".+/.+", repo)) {
    stop("`repo` must be a single string of the form 'owner/name'.", call. = FALSE)
  }
  repo
}

normalize_tag <- function(tag) {
  if (!is.character(tag) || length(tag) != 1 || !nzchar(tag)) {
    stop("`tag` must be a non-empty string.", call. = FALSE)
  }
  tag
}

normalize_files <- function(files) {
  if (length(files) == 0) {
    return(character())
  }
  if (!is.character(files)) {
    stop("`files` must be a character vector.", call. = FALSE)
  }

  missing <- files[!file.exists(files)]
  if (length(missing) > 0) {
    stop(
      "The following files do not exist locally: ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }

  normalizePath(files, winslash = "/", mustWork = TRUE)
}

check_sf_available <- function() {
  requireNamespace("sf", quietly = TRUE)
}

http_head <- function(url) {
  HEAD(url, config(followlocation = FALSE))
}
