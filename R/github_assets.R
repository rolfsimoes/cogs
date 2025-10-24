#' Resolve a GitHub release asset to a signed download URL
#'
#' Performs a `HEAD` request against the GitHub Releases download endpoint and
#' extracts the temporary, signed URL that GitHub returns via the `Location`
#' header. The function never follows redirects to avoid downloading the asset.
#'
#' @param file Path or file name of the release asset.
#' @param repo Repository slug in the form `"owner/name"`.
#' @param tag Release tag that contains the asset.
#'
#' @return A single string with the signed asset URL.
#' @export
#'
#' @examples
#' \dontrun{
#' get_githubasset_url(
#'   file = "LANDSAT_OLI_2017_corrected.tif",
#'   repo = "rolfsimoes/cogs",
#'   tag = "cog-test"
#' )
#' }
#'
#' @importFrom glue glue
#' @importFrom httr HEAD headers status_code config
get_githubasset_url <- function(file,
                                repo = get_default_repo(),
                                tag = get_default_tag()) {
  stopifnot(length(file) == 1)
  stopifnot(length(repo) == 1)
  stopifnot(length(tag) == 1)

  asset <- basename(file)
  if (!nzchar(asset)) {
    stop("`file` must contain a valid asset name.", call. = FALSE)
  }

  if (!grepl(".+/.+", repo)) {
    stop("`repo` must be of the form 'owner/name'.", call. = FALSE)
  }

  url <- glue::glue("https://github.com/{repo}/releases/download/{tag}/{asset}")

  resp <- http_head(url)
  status <- status_code(resp)
  if (status >= 400) {
    stop(
      glue::glue(
        "GitHub returned status {status} when resolving {asset} in {repo}@{tag}."
      ),
      call. = FALSE
    )
  }

  location <- headers(resp)[["location"]]
  if (is.null(location) || !nzchar(location)) {
    stop(
      "GitHub did not return a signed URL for the asset; check the file name and release tag.",
      call. = FALSE
    )
  }

  location
}
