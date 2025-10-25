#' Query GDAL runtime driver capabilities
#'
#' @param format Character scalar (e.g. `"GTiff"` or `"COG"`).
#' @return A list with elements:
#' \itemize{
#'   \item version: GDAL version string
#'   \item driver: Driver short name
#'   \item has_create: TRUE/FALSE if `GDALCreate()` works
#'   \item has_createcopy: TRUE/FALSE if `GDALCreateCopy()` is supported
#'   \item has_virtualio: TRUE/FALSE if /vsimem/ supported
#'   \item datatypes: Character vector of supported GDAL types
#' }
#' @examples
#' rg_gdal_capabilities("COG")
#' rg_gdal_capabilities("GTiff")
#' @export
rg_gdal_capabilities <- function(format) {
  if (!is.character(format) || length(format) != 1) {
    stop("'format' must be a single character string")
  }
  .Call("_rgio_gdal_capabilities", format, PACKAGE = "rgio")
}
