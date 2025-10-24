/*
 * vrt.cpp
 * VRT creation and manipulation using GDAL C++ API
 */

#include <R.h>
#include <Rinternals.h>
#include <gdal.h>
#include <gdal_utils.h>
#include <cpl_conv.h>
#include <cpl_string.h>
#include <cstdio>
#include <cstring>

extern "C" {

/*
 * Entry point for VRT frame creation
 * 
 * @param src Source raster file paths
 * @param bbox Bounding box (xmin, ymin, xmax, ymax)
 * @param width Grid width in pixels
 * @param height Grid height in pixels
 * @param crs Coordinate reference system
 * @param opts Additional VRT options (list)
 * @return VRT file path (character string)
 */
SEXP _rgio_vf(SEXP src, SEXP bbox, SEXP width, SEXP height,
              SEXP crs, SEXP opts) {
  
  /* Register GDAL drivers */
  GDALAllRegister();
  
  /* Extract parameters */
  int n_sources = length(src);
  double *bbox_vals = REAL(bbox);
  double xmin = bbox_vals[0];
  double ymin = bbox_vals[1];
  double xmax = bbox_vals[2];
  double ymax = bbox_vals[3];
  int grid_width = INTEGER(width)[0];
  int grid_height = INTEGER(height)[0];
  const char *target_crs = CHAR(STRING_ELT(crs, 0));
  
  /* Build source file list */
  char **src_files = (char **)CPLCalloc(n_sources + 1, sizeof(char *));
  for (int i = 0; i < n_sources; i++) {
    src_files[i] = CPLStrdup(CHAR(STRING_ELT(src, i)));
  }
  src_files[n_sources] = NULL;
  
  /* Generate unique VRT filename in /vsimem/ */
  static int vrt_counter = 0;
  char vrt_path[256];
  snprintf(vrt_path, sizeof(vrt_path), "/vsimem/rgio_vrt_%d.vrt", vrt_counter++);
  
  /* Build VRT using GDALBuildVRT */
  char **buildvrt_argv = NULL;
  
  /* Set target extent */
  buildvrt_argv = CSLAddString(buildvrt_argv, "-te");
  char xmin_str[64], ymin_str[64], xmax_str[64], ymax_str[64];
  snprintf(xmin_str, sizeof(xmin_str), "%.15g", xmin);
  snprintf(ymin_str, sizeof(ymin_str), "%.15g", ymin);
  snprintf(xmax_str, sizeof(xmax_str), "%.15g", xmax);
  snprintf(ymax_str, sizeof(ymax_str), "%.15g", ymax);
  buildvrt_argv = CSLAddString(buildvrt_argv, xmin_str);
  buildvrt_argv = CSLAddString(buildvrt_argv, ymin_str);
  buildvrt_argv = CSLAddString(buildvrt_argv, xmax_str);
  buildvrt_argv = CSLAddString(buildvrt_argv, ymax_str);
  
  /* Set target resolution */
  double xres = (xmax - xmin) / grid_width;
  double yres = (ymax - ymin) / grid_height;
  buildvrt_argv = CSLAddString(buildvrt_argv, "-tr");
  char xres_str[64], yres_str[64];
  snprintf(xres_str, sizeof(xres_str), "%.15g", xres);
  snprintf(yres_str, sizeof(yres_str), "%.15g", yres);
  buildvrt_argv = CSLAddString(buildvrt_argv, xres_str);
  buildvrt_argv = CSLAddString(buildvrt_argv, yres_str);
  
  /* Set target CRS */
  buildvrt_argv = CSLAddString(buildvrt_argv, "-a_srs");
  buildvrt_argv = CSLAddString(buildvrt_argv, target_crs);
  
  /* Create build VRT options */
  GDALBuildVRTOptions *buildvrt_options = GDALBuildVRTOptionsNew(buildvrt_argv, NULL);
  CSLDestroy(buildvrt_argv);
  
  if (buildvrt_options == NULL) {
    CSLDestroy(src_files);
    error("Failed to create build VRT options");
  }
  
  /* Open source datasets */
  GDALDatasetH *src_datasets = (GDALDatasetH *)CPLCalloc(n_sources, sizeof(GDALDatasetH));
  for (int i = 0; i < n_sources; i++) {
    src_datasets[i] = GDALOpen(src_files[i], GA_ReadOnly);
    if (src_datasets[i] == NULL) {
      /* Clean up already opened datasets */
      for (int j = 0; j < i; j++) {
        GDALClose(src_datasets[j]);
      }
      CPLFree(src_datasets);
      GDALBuildVRTOptionsFree(buildvrt_options);
      CSLDestroy(src_files);
      error("Failed to open source file: %s", src_files[i]);
    }
  }
  
  /* Build VRT */
  int err_flag = 0;
  GDALDatasetH vrt_ds = GDALBuildVRT(vrt_path, n_sources, src_datasets,
                                      (const char * const *)src_files,
                                      buildvrt_options, &err_flag);
  
  /* Clean up source datasets */
  for (int i = 0; i < n_sources; i++) {
    GDALClose(src_datasets[i]);
  }
  CPLFree(src_datasets);
  GDALBuildVRTOptionsFree(buildvrt_options);
  CSLDestroy(src_files);
  
  if (vrt_ds == NULL || err_flag != 0) {
    error("VRT creation failed");
  }
  
  /* Close VRT dataset (it remains in /vsimem/) */
  GDALClose(vrt_ds);
  
  /* Return VRT path */
  SEXP result = PROTECT(allocVector(STRSXP, 1));
  SET_STRING_ELT(result, 0, mkChar(vrt_path));
  UNPROTECT(1);
  
  return result;
}

/*
 * Retrieve palette from VRT
 */
SEXP _rgio_vrt_palette_get(SEXP file) {
  const char *file_path = CHAR(STRING_ELT(file, 0));
  GDALDatasetH ds = GDALOpen(file_path, GA_ReadOnly);
  if (ds == NULL) {
    error("Failed to open VRT: %s", file_path);
  }

  GDALRasterBandH band = GDALGetRasterBand(ds, 1);
  if (band == NULL) {
    GDALClose(ds);
    error("Failed to access band in VRT: %s", file_path);
  }

  GDALColorTableH ct = GDALGetRasterColorTable(band);
  if (ct == NULL) {
    GDALClose(ds);
    SEXP empty = PROTECT(allocVector(VECSXP, 2));
    SET_VECTOR_ELT(empty, 0, allocVector(INTSXP, 0)); /* values */
    SET_VECTOR_ELT(empty, 1, allocMatrix(INTSXP, 0, 4)); /* colors */
    SEXP names = PROTECT(allocVector(STRSXP, 2));
    SET_STRING_ELT(names, 0, mkChar("values"));
    SET_STRING_ELT(names, 1, mkChar("colors"));
    setAttrib(empty, R_NamesSymbol, names);
    UNPROTECT(2);
    return empty;
  }

  int count = GDALGetColorEntryCount(ct);
  SEXP values = PROTECT(allocVector(INTSXP, count));
  SEXP colors = PROTECT(allocMatrix(INTSXP, count, 4));
  int *val_ptr = INTEGER(values);
  int *col_ptr = INTEGER(colors);

  for (int i = 0; i < count; i++) {
    val_ptr[i] = i;
    const GDALColorEntry *entry = GDALGetColorEntry(ct, i);
    if (entry != NULL) {
      col_ptr[i] = entry->c1;
      col_ptr[i + count] = entry->c2;
      col_ptr[i + 2 * count] = entry->c3;
      col_ptr[i + 3 * count] = entry->c4;
    } else {
      col_ptr[i] = 0;
      col_ptr[i + count] = 0;
      col_ptr[i + 2 * count] = 0;
      col_ptr[i + 3 * count] = 0;
    }
  }

  GDALClose(ds);

  SEXP result = PROTECT(allocVector(VECSXP, 2));
  SET_VECTOR_ELT(result, 0, values);
  SET_VECTOR_ELT(result, 1, colors);
  SEXP names = PROTECT(allocVector(STRSXP, 2));
  SET_STRING_ELT(names, 0, mkChar("values"));
  SET_STRING_ELT(names, 1, mkChar("colors"));
  setAttrib(result, R_NamesSymbol, names);
  UNPROTECT(4);
  return result;
}

/*
 * Set palette on VRT
 */
SEXP _rgio_vrt_palette_set(SEXP file, SEXP values, SEXP colors,
                           SEXP nrows) {
  const char *file_path = CHAR(STRING_ELT(file, 0));
  int count = INTEGER(nrows)[0];
  if (count <= 0) {
    error("Palette must contain at least one entry");
  }

  GDALDatasetH ds = GDALOpen(file_path, GA_Update);
  if (ds == NULL) {
    error("Failed to open VRT for update: %s", file_path);
  }

  GDALRasterBandH band = GDALGetRasterBand(ds, 1);
  if (band == NULL) {
    GDALClose(ds);
    error("Failed to access band in VRT: %s", file_path);
  }

  GDALColorTableH ct = GDALCreateColorTable(GPI_RGB);
  if (ct == NULL) {
    GDALClose(ds);
    error("Failed to allocate color table");
  }

  const int *val_ptr = INTEGER(values);
  const int *col_ptr = INTEGER(colors);
  for (int i = 0; i < count; i++) {
    GDALColorEntry entry;
    entry.c1 = static_cast<short>(col_ptr[i]);
    entry.c2 = static_cast<short>(col_ptr[i + count]);
    entry.c3 = static_cast<short>(col_ptr[i + 2 * count]);
    entry.c4 = static_cast<short>(col_ptr[i + 3 * count]);
    GDALSetColorEntry(ct, val_ptr[i], &entry);
  }

  CPLErr err = GDALSetRasterColorTable(band, ct);
  GDALDestroyColorTable(ct);
  if (err != CE_None) {
    GDALClose(ds);
    error("Failed to assign color table to VRT: %s", file_path);
  }

  GDALSetRasterColorInterpretation(band, GCI_PaletteIndex);
  GDALClose(ds);
  return file;
}

/*
 * Retrieve legend (categories) from VRT
 */
SEXP _rgio_vrt_legend_get(SEXP file) {
  const char *file_path = CHAR(STRING_ELT(file, 0));
  GDALDatasetH ds = GDALOpen(file_path, GA_ReadOnly);
  if (ds == NULL) {
    error("Failed to open VRT: %s", file_path);
  }

  GDALRasterBandH band = GDALGetRasterBand(ds, 1);
  if (band == NULL) {
    GDALClose(ds);
    error("Failed to access band in VRT: %s", file_path);
  }

  GDALColorTableH ct = GDALGetRasterColorTable(band);
  int count = ct ? GDALGetColorEntryCount(ct) : 0;
  char **names = GDALGetRasterCategoryNames(band);

  SEXP result = PROTECT(allocVector(STRSXP, count));
  for (int i = 0; i < count; i++) {
    if (names != NULL && names[i] != NULL) {
      SET_STRING_ELT(result, i, mkChar(names[i]));
    } else {
      SET_STRING_ELT(result, i, NA_STRING);
    }
  }

  GDALClose(ds);
  UNPROTECT(1);
  return result;
}

/*
 * Update legend (categories) on VRT
 */
SEXP _rgio_vrt_legend_set(SEXP file, SEXP values, SEXP labels) {
  const char *file_path = CHAR(STRING_ELT(file, 0));
  int n_vals = length(values);
  if (n_vals == 0) {
    error("Legend update requires at least one value");
  }

  GDALDatasetH ds = GDALOpen(file_path, GA_Update);
  if (ds == NULL) {
    error("Failed to open VRT for update: %s", file_path);
  }

  GDALRasterBandH band = GDALGetRasterBand(ds, 1);
  if (band == NULL) {
    GDALClose(ds);
    error("Failed to access band in VRT: %s", file_path);
  }

  GDALColorTableH ct = GDALGetRasterColorTable(band);
  int count = ct ? GDALGetColorEntryCount(ct) : 0;

  int max_value = 0;
  const int *vals = INTEGER(values);
  for (int i = 0; i < n_vals; i++) {
    if (vals[i] > max_value) {
      max_value = vals[i];
    }
  }

  if (max_value + 1 > count) {
    count = max_value + 1;
  }

  char **existing = GDALGetRasterCategoryNames(band);
  char **names = (char **) CPLCalloc(count + 1, sizeof(char *));

  for (int i = 0; i < count; i++) {
    if (existing != NULL && existing[i] != NULL) {
      names[i] = CPLStrdup(existing[i]);
    } else {
      names[i] = NULL;
    }
  }
  names[count] = NULL;

  for (int i = 0; i < n_vals; i++) {
    int idx = vals[i];
    if (idx < 0 || idx >= count) {
      continue;
    }
    if (names[idx] != NULL) {
      CPLFree(names[idx]);
    }
    names[idx] = CPLStrdup(CHAR(STRING_ELT(labels, i)));
  }

  if (GDALSetRasterCategoryNames(band, names) != CE_None) {
    CSLDestroy(names);
    GDALClose(ds);
    error("Failed to update VRT legend categories");
  }

  CSLDestroy(names);
  GDALClose(ds);
  return file;
}

} /* extern "C" */
