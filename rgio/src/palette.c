#include <R.h>
#include <Rinternals.h>

#include <gdal.h>
#include <cpl_conv.h>

SEXP _rgio_pal(SEXP file, SEXP indices) {
  GDALAllRegister();

  if (TYPEOF(file) != STRSXP || LENGTH(file) != 1) {
    error("'file' must be a single character string");
  }
  if (TYPEOF(indices) != INTSXP) {
    error("'indices' must be an integer vector");
  }

  const char *filepath = CHAR(STRING_ELT(file, 0));
  const int nIndices = LENGTH(indices);
  const int *index_values = INTEGER(indices);

  GDALDatasetH dataset = GDALOpen(filepath, GA_ReadOnly);
  if (dataset == NULL) {
    error("Failed to open file for reading: %s", filepath);
  }

  GDALRasterBandH band = GDALGetRasterBand(dataset, 1);
  if (band == NULL) {
    GDALClose(dataset);
    error("Failed to access raster band in %s", filepath);
  }

  GDALColorTableH color_table = GDALGetRasterColorTable(band);
  if (color_table == NULL) {
    GDALClose(dataset);
    error("Raster %s does not have a color table", filepath);
  }

  SEXP colors = PROTECT(allocMatrix(INTSXP, nIndices, 4));
  int *color_ptr = INTEGER(colors);

  char **category_names = GDALGetRasterCategoryNames(band);
  int category_count = 0;
  if (category_names != NULL) {
    while (category_names[category_count] != NULL) {
      category_count++;
    }
  }

  SEXP labels = PROTECT(allocVector(STRSXP, nIndices));

  for (int i = 0; i < nIndices; i++) {
    const int idx = index_values[i];
    const GDALColorEntry *entry = GDALGetColorEntry(color_table, idx);

    if (entry == NULL) {
      GDALClose(dataset);
      UNPROTECT(2);
      error("Color entry %d not found in raster %s", idx, filepath);
    }

    color_ptr[i] = entry->c1;
    color_ptr[i + nIndices] = entry->c2;
    color_ptr[i + 2 * nIndices] = entry->c3;
    color_ptr[i + 3 * nIndices] = entry->c4;

    if (category_names != NULL && idx >= 0 && idx < category_count && category_names[idx] != NULL) {
      SET_STRING_ELT(labels, i, mkChar(category_names[idx]));
    } else {
      SET_STRING_ELT(labels, i, NA_STRING);
    }
  }

  GDALClose(dataset);

  SEXP result = PROTECT(allocVector(VECSXP, 2));
  SET_VECTOR_ELT(result, 0, colors);
  SET_VECTOR_ELT(result, 1, labels);

  SEXP names = PROTECT(allocVector(STRSXP, 2));
  SET_STRING_ELT(names, 0, mkChar("colors"));
  SET_STRING_ELT(names, 1, mkChar("labels"));
  setAttrib(result, R_NamesSymbol, names);

  UNPROTECT(4);
  return result;
}
