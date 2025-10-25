/*
 * info.c
 * Dataset metadata inspection for rgio
 */

#include <R.h>
#include <Rinternals.h>
#include <gdal.h>
#include <cpl_conv.h>
#include <string.h>

/* -------------------------------------------------------------------------- */
/*  _rgio_info                                                                */
/* -------------------------------------------------------------------------- */
/*
 * Inspect raster dataset metadata and return as an R list.
 *
 * Returned fields:
 *   $driver        - short driver name (e.g., "GTiff", "COG")
 *   $driver_long   - long driver name (e.g., "GeoTIFF")
 *   $datatype      - raster data type (e.g., "UInt16")
 *   $width, $height, $bands - raster dimensions
 *   $gt            - GeoTransform (length 6, or NA)
 *   $crs           - projection WKT string or NA
 *   $nodata        - nodata value (numeric or NA)
 *   $color_table   - logical (TRUE if has color table)
 *   $categories    - logical (TRUE if has categories)
 */

SEXP _rgio_info(SEXP path)
{
  const char *dataset_path = CHAR(STRING_ELT(path, 0));
  GDALAllRegister();

  GDALDatasetH ds = GDALOpen(dataset_path, GA_ReadOnly);
  if (ds == NULL) {
    error("Failed to open dataset: %s", dataset_path);
  }

  /* Driver information */
  GDALDriverH drv = GDALGetDatasetDriver(ds);
  const char *drv_short = drv ? GDALGetDriverShortName(drv) : "Unknown";
  const char *drv_long  = drv ? GDALGetDriverLongName(drv)  : "Unknown";

  /* Raster dimensions */
  int width       = GDALGetRasterXSize(ds);
  int height      = GDALGetRasterYSize(ds);
  int band_count  = GDALGetRasterCount(ds);

  /* Band and datatype */
  GDALRasterBandH band = NULL;
  GDALDataType dtype   = GDT_Unknown;
  if (band_count > 0) {
    band = GDALGetRasterBand(ds, 1);
    if (band != NULL)
      dtype = GDALGetRasterDataType(band);
  }

  const char *dtype_name = GDALGetDataTypeName(dtype);
  if (dtype_name == NULL)
    dtype_name = "Unknown";

  /* GeoTransform */
  double gt_vals[6];
  int has_gt = GDALGetGeoTransform(ds, gt_vals);

  SEXP gt = PROTECT(allocVector(REALSXP, 6));
  double *gt_ptr = REAL(gt);
  if (has_gt == CE_None) {
    for (int i = 0; i < 6; i++)
      gt_ptr[i] = gt_vals[i];
  } else {
    for (int i = 0; i < 6; i++)
      gt_ptr[i] = NA_REAL;
  }

  /* CRS (projection) */
  const char *proj = GDALGetProjectionRef(ds);
  SEXP crs = PROTECT(allocVector(STRSXP, 1));
  if (proj != NULL && strlen(proj) > 0) {
    SET_STRING_ELT(crs, 0, Rf_mkChar(proj));
  } else {
    SET_STRING_ELT(crs, 0, NA_STRING);
  }

  /* NoData value */
  double nodata_val = NA_REAL;
  int has_nodata_flag = 0;
  if (band != NULL) {
    nodata_val = GDALGetRasterNoDataValue(band, &has_nodata_flag);
    if (!has_nodata_flag)
      nodata_val = NA_REAL;
  }

  /* Color table and categories */
  int has_color_table = 0;
  int has_categories  = 0;

  if (band != NULL) {
    GDALColorTableH ct = GDALGetRasterColorTable(band);
    if (ct != NULL)
      has_color_table = 1;

    char **categories = GDALGetRasterCategoryNames(band);
    if (categories != NULL && categories[0] != NULL) {
      for (int i = 0; categories[i] != NULL; i++) {
        if (categories[i][0] != '\0') {
          has_categories = 1;
          break;
        }
      }
    }
  }

  /* ---------------------------------------------------------------------- */
  /* Build return list                                                      */
  /* ---------------------------------------------------------------------- */

  const int n_items = 11;
  SEXP result = PROTECT(allocVector(VECSXP, n_items));
  SEXP names  = PROTECT(allocVector(STRSXP, n_items));

  int idx = 0;

  /* 0: driver short */
  SET_VECTOR_ELT(result, idx, Rf_mkString(drv_short));
  SET_STRING_ELT(names, idx++, Rf_mkChar("driver"));

  /* 1: driver long */
  SET_VECTOR_ELT(result, idx, Rf_mkString(drv_long));
  SET_STRING_ELT(names, idx++, Rf_mkChar("driver_long"));

  /* 2: datatype */
  SET_VECTOR_ELT(result, idx, Rf_mkString(dtype_name));
  SET_STRING_ELT(names, idx++, Rf_mkChar("datatype"));

  /* 3: width */
  SET_VECTOR_ELT(result, idx, ScalarInteger(width));
  SET_STRING_ELT(names, idx++, Rf_mkChar("width"));

  /* 4: height */
  SET_VECTOR_ELT(result, idx, ScalarInteger(height));
  SET_STRING_ELT(names, idx++, Rf_mkChar("height"));

  /* 5: bands */
  SET_VECTOR_ELT(result, idx, ScalarInteger(band_count));
  SET_STRING_ELT(names, idx++, Rf_mkChar("bands"));

  /* 6: GeoTransform */
  SET_VECTOR_ELT(result, idx, gt);
  SET_STRING_ELT(names, idx++, Rf_mkChar("gt"));

  /* 7: CRS */
  SET_VECTOR_ELT(result, idx, crs);
  SET_STRING_ELT(names, idx++, Rf_mkChar("crs"));

  /* 8: nodata */
  SET_VECTOR_ELT(result, idx, ScalarReal(nodata_val));
  SET_STRING_ELT(names, idx++, Rf_mkChar("nodata"));

  /* 9: color table */
  SET_VECTOR_ELT(result, idx, ScalarLogical(has_color_table));
  SET_STRING_ELT(names, idx++, Rf_mkChar("color_table"));

  /* 10: categories */
  SET_VECTOR_ELT(result, idx, ScalarLogical(has_categories));
  SET_STRING_ELT(names, idx++, Rf_mkChar("categories"));

  setAttrib(result, R_NamesSymbol, names);

  GDALClose(ds);
  UNPROTECT(4); /* gt, crs, result, names */
  return result;
}
