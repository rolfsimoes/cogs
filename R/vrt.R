#' Generate VRT wrappers for GeoTIFF release assets
#'
#' Creates GDAL VRT files for each Cloud-Optimized GeoTIFF stored as a GitHub
#' release asset. The function resolves the signed asset URL to emit a
#' VRT that references the remote file via `/vsicurl/`.
#'
#' @param repo Repository slug in the form `"owner/name"`. Uses the package
#'   default if not supplied.
#' @param tag Release tag. Uses the package default if not supplied.
#'
#' @return A character vector with the paths of the VRT files that were created.
#' @export
#'
#' @examples
#' \dontrun{
#' make_vrt(repo = "rolfsimoes/cogs", tag = "cog-test")
#' }
#'
#' @importFrom piggyback pb_list
make_vrt <- function(repo = get_default_repo(),
                     tag = get_default_tag()) {
    if (!check_sf_available()) {
        stop(
            "Package 'sf' must be installed to build VRT files. ",
            "Install it or create the VRT manually.",
            call. = FALSE
        )
    }

    repo <- normalize_repo(repo)
    tag <- normalize_tag(tag)

    refresh_piggyback_cache()
    assets <- pb_list_safe(repo = repo, tag = tag)
    if (nrow(assets) == 0) {
        return(character())
    }

    tif_mask <- grepl("\\.tif(f)?$", assets$file_name, ignore.case = TRUE)
    tifs <- assets$file_name[tif_mask]
    if (length(tifs) == 0) {
        return(character())
    }

    vrt_paths <- character(length(tifs))
    for (i in seq_along(tifs)) {
        tif_name <- tifs[[i]]
        signed_url <- get_githubasset_url(
            file = tif_name,
            repo = repo,
            tag = tag
        )

        destination <- sub("\\.tif(f)?$", ".vrt", tif_name, ignore.case = TRUE)
        gdal_utils_safe(
            util = "translate",
            source = paste0("/vsicurl/", signed_url),
            destination = destination,
            options = c("-of", "VRT"),
            quiet = TRUE
        )

        vrt_paths[[i]] <- normalizePath(destination, winslash = "/", mustWork = FALSE)
    }

    vrt_paths
}
