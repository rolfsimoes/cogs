#include <R.h>
#include <Rinternals.h>
#include <gdal.h>
#include "gdal_utils.h"
#include <cpl_conv.h>

/*
 * _rgio_gdal_capabilities
 * Returns runtime GDAL driver capabilities for a given format.
 */
SEXP _rgio_gdal_capabilities(SEXP fmt)
{
  if (TYPEOF(fmt) != STRSXP || Rf_length(fmt) != 1) {
    error("'format' must be a single character string");
  }

  const char *format = CHAR(STRING_ELT(fmt, 0));
  GDALAllRegister();

  /* Get driver */
  GDALDriverH driver = GDALGetDriverByName(format);
  if (driver == NULL) {
    error("Driver not found: %s", format);
  }

  /* ---------------------------------------------------------------------- */
  /* Collect metadata flags                                                 */
  /* ---------------------------------------------------------------------- */
  int has_create     = GDALGetMetadataItem(driver, GDAL_DCAP_CREATE, NULL) != NULL;
  int has_createcopy = GDALGetMetadataItem(driver, GDAL_DCAP_CREATECOPY, NULL) != NULL;
  int has_virtualio  = GDALGetMetadataItem(driver, GDAL_DCAP_VIRTUALIO, NULL) != NULL;

  /* ---------------------------------------------------------------------- */
  /* Test creation in /vsimem/ if CREATE supported                          */
  /* ---------------------------------------------------------------------- */
  if (has_create) {
    const char *path = "/vsimem/test_cap.tif";
    GDALDatasetH ds = create_raster_dataset(
      path,
      format,
      "Byte",
      NULL,
      1,
      1,
      0.0,
      0.0,
      NULL,
      1,
      NULL
    );
    if (ds != NULL) {
      GDALClose(ds);
      VSIUnlink(path);
    } else {
      has_create = 0;
    }
  }

  /* ---------------------------------------------------------------------- */
  /* Prepare result                                                         */
  /* ---------------------------------------------------------------------- */
  const char *version = GDALVersionInfo("RELEASE_NAME");

  SEXP datatypes = PROTECT(allocVector(STRSXP, 10));
  const char *types[10] = {"Byte", "UInt16", "Int16", "UInt32", "Int32",
                           "Float32", "Float64", "CInt16", "CInt32", "CFloat64"};
  for (int i = 0; i < 10; i++)
    SET_STRING_ELT(datatypes, i, mkChar(types[i]));

  /* Result list */
  SEXP result = PROTECT(allocVector(VECSXP, 6));
  SEXP names  = PROTECT(allocVector(STRSXP, 6));

  SET_VECTOR_ELT(result, 0, mkString(version));
  SET_STRING_ELT(names, 0, mkChar("version"));

  SET_VECTOR_ELT(result, 1, mkString(format));
  SET_STRING_ELT(names, 1, mkChar("driver"));

  SET_VECTOR_ELT(result, 2, ScalarLogical(has_create));
  SET_STRING_ELT(names, 2, mkChar("has_create"));

  SET_VECTOR_ELT(result, 3, ScalarLogical(has_createcopy));
  SET_STRING_ELT(names, 3, mkChar("has_createcopy"));

  SET_VECTOR_ELT(result, 4, ScalarLogical(has_virtualio));
  SET_STRING_ELT(names, 4, mkChar("has_virtualio"));

  SET_VECTOR_ELT(result, 5, datatypes);
  SET_STRING_ELT(names, 5, mkChar("datatypes"));

  setAttrib(result, R_NamesSymbol, names);
  UNPROTECT(3);

  return result;
}
