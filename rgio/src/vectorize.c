/*
 * vectorize.c
 * Raster to vector polygonization
 */

#include <R.h>
#include <Rinternals.h>
#include <gdal.h>
#include <ogr_api.h>
#include <ogr_srs_api.h>
#include <gdal_alg.h>
#include <cpl_conv.h>
#include <cpl_string.h>
#include <string.h>

SEXP _rgio_vec(SEXP src, SEXP dst, SEXP format, SEXP band,
               SEXP field, SEXP connectedness, SEXP mask, SEXP co) {

  const char *src_path = CHAR(STRING_ELT(src, 0));
  const char *dst_path = CHAR(STRING_ELT(dst, 0));
  const char *driver_name = CHAR(STRING_ELT(format, 0));
  const char *field_name = CHAR(STRING_ELT(field, 0));
  int band_index = INTEGER(band)[0];
  int conn = INTEGER(connectedness)[0];
  const char *mask_path = CHAR(STRING_ELT(mask, 0));

  GDALAllRegister();
  OGRRegisterAll();

  GDALDatasetH src_ds = GDALOpen(src_path, GA_ReadOnly);
  if (src_ds == NULL) {
    error("Failed to open raster dataset: %s", src_path);
  }

  GDALRasterBandH src_band = GDALGetRasterBand(src_ds, band_index);
  if (src_band == NULL) {
    GDALClose(src_ds);
    error("Raster band %d not available in %s", band_index, src_path);
  }

  GDALDatasetH mask_ds = NULL;
  GDALRasterBandH mask_band = NULL;
  if (mask_path[0] != '\0') {
    mask_ds = GDALOpen(mask_path, GA_ReadOnly);
    if (mask_ds == NULL) {
      GDALClose(src_ds);
      error("Failed to open mask dataset: %s", mask_path);
    }
    mask_band = GDALGetRasterBand(mask_ds, 1);
    if (mask_band == NULL) {
      GDALClose(mask_ds);
      GDALClose(src_ds);
      error("Mask dataset does not contain band 1: %s", mask_path);
    }
  }

  GDALDriverH drv = GDALGetDriverByName(driver_name);
  if (drv == NULL) {
    if (mask_ds) GDALClose(mask_ds);
    GDALClose(src_ds);
    error("Vector driver not available: %s", driver_name);
  }

  /* Remove existing dataset if present */
  GDALDeleteDataset(drv, dst_path);

  char **create_opts = NULL;
  int co_len = LENGTH(co);
  for (int i = 0; i < co_len; i++) {
    create_opts = CSLAddString(create_opts, CHAR(STRING_ELT(co, i)));
  }

  GDALDatasetH dst_ds = GDALCreate(drv, dst_path, 0, 0, 0, GDT_Unknown, create_opts);
  CSLDestroy(create_opts);

  if (dst_ds == NULL) {
    if (mask_ds) GDALClose(mask_ds);
    GDALClose(src_ds);
    error("Failed to create vector dataset: %s", dst_path);
  }

  const char *proj = GDALGetProjectionRef(src_ds);
  OGRSpatialReferenceH srs = NULL;
  if (proj != NULL && strlen(proj) > 0) {
    srs = OSRNewSpatialReference(NULL);
    if (OSRSetFromUserInput(srs, proj) != OGRERR_NONE) {
      OSRDestroySpatialReference(srs);
      srs = NULL;
    }
  }

  OGRLayerH layer = GDALDatasetCreateLayer(dst_ds, "polygons", srs, wkbPolygon, NULL);
  if (srs != NULL) {
    OSRDestroySpatialReference(srs);
  }

  if (layer == NULL) {
    GDALClose(dst_ds);
    if (mask_ds) GDALClose(mask_ds);
    GDALClose(src_ds);
    error("Failed to create output layer in %s", dst_path);
  }

  OGRFieldDefnH fld = OGR_Fld_Create(field_name, OFTInteger);
  if (OGR_L_CreateField(layer, fld, TRUE) != OGRERR_NONE) {
    OGR_Fld_Destroy(fld);
    GDALClose(dst_ds);
    if (mask_ds) GDALClose(mask_ds);
    GDALClose(src_ds);
    error("Failed to create attribute field '%s'", field_name);
  }
  OGR_Fld_Destroy(fld);

  int field_index = OGR_L_FindFieldIndex(layer, field_name, TRUE);
  if (field_index < 0) {
    GDALClose(dst_ds);
    if (mask_ds) GDALClose(mask_ds);
    GDALClose(src_ds);
    error("Unable to locate field '%s' in output layer", field_name);
  }

  char **poly_opts = NULL;
  if (conn == 8) {
    poly_opts = CSLAddString(poly_opts, "8CONNECTED=YES");
  } else {
    poly_opts = CSLAddString(poly_opts, "8CONNECTED=NO");
  }

  CPLErr err = GDALPolygonize(src_band, mask_band, layer, field_index, poly_opts, NULL, NULL);
  CSLDestroy(poly_opts);

  if (mask_ds) GDALClose(mask_ds);
  GDALClose(dst_ds);
  GDALClose(src_ds);

  if (err != CE_None) {
    error("Polygonize operation failed for %s", src_path);
  }

  return dst;
}
