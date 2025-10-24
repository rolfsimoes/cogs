#' Create a GitHub release if it is missing
#'
#' Ensures a release exists for a given repository and tag. When the release
#' already exists the function is a no-op, otherwise it delegates to
#' [piggyback::pb_new_release()].
#'
#' @param repo Repository slug in the form `"owner/name"`.
#' @param tag Release tag to ensure.
#' @param body Markdown body that describes the release.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' new_githubrelease(
#'   repo = "rolfsimoes/cogs",
#'   tag = "cog-test",
#'   body = "Cloud-Optimized GeoTIFF release"
#' )
#' }
#'
#' @importFrom piggyback pb_releases pb_new_release
new_githubrelease <- function(repo,
                              tag,
                              body = "") {
  repo <- normalize_repo(repo)
  tag <- normalize_tag(tag)

  releases <- pb_releases_safe(repo = repo)
  if (!tag %in% releases$tag_name) {
    pb_new_release_safe(repo = repo, tag = tag, body = body)
  }

  refresh_piggyback_cache()

  invisible(tag)
}

#' Upload assets to a GitHub release
#'
#' Uploads one or more files to a GitHub release, skipping assets that already
#' exist unless `overwrite = TRUE`.
#'
#' @param files Character vector of file paths to upload.
#' @param repo Repository slug in the form `"owner/name"`. Uses the package
#'   default if not supplied.
#' @param tag Release tag. Uses the package default if not supplied.
#' @param overwrite Should matching files be overwritten on GitHub?
#'
#' @return Invisibly returns the vector of files that were uploaded.
#' @export
#'
#' @examples
#' \dontrun{
#' upload_githubassets(
#'   files = list.files("data/derived", "tif$", full.names = TRUE),
#'   repo = "rolfsimoes/cogs",
#'   tag = "cog-test"
#' )
#' }
#'
#' @importFrom piggyback pb_releases pb_list pb_upload
#' @importFrom glue glue
upload_githubassets <- function(files,
                                repo = get_default_repo(),
                                tag = get_default_tag(),
                                overwrite = FALSE) {
  repo <- normalize_repo(repo)
  tag <- normalize_tag(tag)
  files <- normalize_files(files)

  if (length(files) == 0) {
    return(invisible(character()))
  }

  releases <- pb_releases_safe(repo = repo)
  if (!tag %in% releases$tag_name) {
    stop(
      glue::glue("Release '{tag}' does not exist for {repo}. Create it first."),
      call. = FALSE
    )
  }

  existing <- pb_list_safe(repo = repo, tag = tag)
  existing_names <- existing$file_name

  uploaded <- character()
  for (path in files) {
    asset <- basename(path)
    should_upload <- overwrite || !(asset %in% existing_names)
    if (!should_upload) {
      next
    }

    pb_upload_safe(
      file = path,
      repo = repo,
      tag = tag,
      overwrite = overwrite
    )
    uploaded <- c(uploaded, path)
  }

  refresh_piggyback_cache()

  invisible(uploaded)
}
