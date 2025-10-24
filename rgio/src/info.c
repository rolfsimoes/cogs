/*
 * info.c
 * Dataset metadata inspection
 */

#include <R.h>
#include <Rinternals.h>
#include <gdal.h>
#include <cpl_conv.h>
#include <string.h>

SEXP _rgio_info(SEXP path) {
  const char *dataset_path = CHAR(STRING_ELT(path, 0));
  GDALAllRegister();

  GDALDatasetH ds = GDALOpen(dataset_path, GA_ReadOnly);
  if (ds == NULL) {
    error("Failed to open dataset: %s", dataset_path);
  }

  int width = GDALGetRasterXSize(ds);
  int height = GDALGetRasterYSize(ds);
  int band_count = GDALGetRasterCount(ds);

  GDALRasterBandH band = NULL;
  GDALDataType dtype = GDT_Unknown;
  if (band_count > 0) {
    band = GDALGetRasterBand(ds, 1);
    if (band != NULL) {
      dtype = GDALGetRasterDataType(band);
    }
  }

  const char *dtype_name = GDALGetDataTypeName(dtype);
  if (dtype_name == NULL) {
    dtype_name = "Unknown";
  }

  double gt_vals[6];
  int has_gt = GDALGetGeoTransform(ds, gt_vals);

  SEXP gt = PROTECT(allocVector(REALSXP, 6));
  double *gt_ptr = REAL(gt);
  if (has_gt == CE_None) {
    for (int i = 0; i < 6; i++) {
      gt_ptr[i] = gt_vals[i];
    }
  } else {
    for (int i = 0; i < 6; i++) {
      gt_ptr[i] = NA_REAL;
    }
  }

  const char *proj = GDALGetProjectionRef(ds);
  SEXP crs = PROTECT(allocVector(STRSXP, 1));
  if (proj != NULL && strlen(proj) > 0) {
    SET_STRING_ELT(crs, 0, mkChar(proj));
  } else {
    SET_STRING_ELT(crs, 0, NA_STRING);
  }

  double nodata_val = NA_REAL;
  int has_nodata_flag = 0;
  if (band != NULL) {
    nodata_val = GDALGetRasterNoDataValue(band, &has_nodata_flag);
    if (!has_nodata_flag) {
      nodata_val = NA_REAL;
    }
  }

  int has_color_table = 0;
  int has_categories = 0;
  if (band != NULL) {
    GDALColorTableH ct = GDALGetRasterColorTable(band);
    if (ct != NULL) {
      has_color_table = 1;
      char **categories = GDALGetRasterCategoryNames(band);
      if (categories != NULL) {
        for (int i = 0; categories[i] != NULL; i++) {
          if (categories[i][0] != '\0') {
            has_categories = 1;
            break;
          }
        }
      }
    }
  }

  SEXP result = PROTECT(allocVector(VECSXP, 9));
  SEXP names = PROTECT(allocVector(STRSXP, 9));

  SET_VECTOR_ELT(result, 0, ScalarInteger(width));
  SET_STRING_ELT(names, 0, mkChar("width"));

  SET_VECTOR_ELT(result, 1, ScalarInteger(height));
  SET_STRING_ELT(names, 1, mkChar("height"));

  SET_VECTOR_ELT(result, 2, ScalarInteger(band_count));
  SET_STRING_ELT(names, 2, mkChar("bands"));

  SET_VECTOR_ELT(result, 3, mkString(dtype_name));
  SET_STRING_ELT(names, 3, mkChar("dtype"));

  SET_VECTOR_ELT(result, 4, gt);
  SET_STRING_ELT(names, 4, mkChar("gt"));

  SET_VECTOR_ELT(result, 5, crs);
  SET_STRING_ELT(names, 5, mkChar("crs"));

  SET_VECTOR_ELT(result, 6, ScalarReal(nodata_val));
  SET_STRING_ELT(names, 6, mkChar("nodata"));

  SET_VECTOR_ELT(result, 7, ScalarLogical(has_color_table));
  SET_STRING_ELT(names, 7, mkChar("color_table"));

  SET_VECTOR_ELT(result, 8, ScalarLogical(has_categories));
  SET_STRING_ELT(names, 8, mkChar("categories"));

  setAttrib(result, R_NamesSymbol, names);

  UNPROTECT(4);
  GDALClose(ds);
  return result;
}
