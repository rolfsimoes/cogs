#include <R.h>
#include <Rinternals.h>

#include <gdal.h>
#include <cpl_conv.h>
#include <cpl_string.h>
#include <ogr_srs_api.h>
#include <string.h>

static GDALDataType parse_datatype(const char *type_str) {
  if (strcmp(type_str, "Byte") == 0) return GDT_Byte;
  if (strcmp(type_str, "UInt16") == 0) return GDT_UInt16;
  if (strcmp(type_str, "Int16") == 0) return GDT_Int16;
  if (strcmp(type_str, "UInt32") == 0) return GDT_UInt32;
  if (strcmp(type_str, "Int32") == 0) return GDT_Int32;
  if (strcmp(type_str, "Float32") == 0) return GDT_Float32;
  if (strcmp(type_str, "Float64") == 0) return GDT_Float64;
  return GDT_Unknown;
}

static void *convert_buffer(const double *src, int n, GDALDataType type,
                            int has_nodata, double nodata_val) {
  void *buffer = NULL;

  switch (type) {
    case GDT_Byte: {
      GByte *tmp = (GByte *) CPLMalloc(sizeof(GByte) * n);
      if (tmp == NULL) return NULL;
      double nd = nodata_val;
      for (int i = 0; i < n; i++) {
        double val = src[i];
        if (R_IsNA(val)) {
          if (has_nodata) {
            if (nd < 0.0 || nd > 255.0)
              error("nodata value %.3f out of range for Byte type", nd);
            tmp[i] = (GByte) nd;
          } else {
            tmp[i] = 0;
          }
        } else {
          if (val < 0.0 || val > 255.0)
            error("Raster value %.3f out of range for Byte type", val);
          tmp[i] = (GByte) val;
        }
      }
      buffer = tmp;
      break;
    }
    case GDT_UInt16: {
      GUInt16 *tmp = (GUInt16 *) CPLMalloc(sizeof(GUInt16) * n);
      if (tmp == NULL) return NULL;
      for (int i = 0; i < n; i++) {
        double val = src[i];
        if (R_IsNA(val)) {
          if (has_nodata) {
            if (nodata_val < 0 || nodata_val > 65535)
              error("nodata value out of range for UInt16 type");
            tmp[i] = (GUInt16) nodata_val;
          } else {
            tmp[i] = 0;
          }
        } else {
          if (val < 0 || val > 65535)
            error("Raster value out of range for UInt16 type");
          tmp[i] = (GUInt16) val;
        }
      }
      buffer = tmp;
      break;
    }
    case GDT_Int16: {
      GInt16 *tmp = (GInt16 *) CPLMalloc(sizeof(GInt16) * n);
      if (tmp == NULL) return NULL;
      for (int i = 0; i < n; i++) {
        double val = src[i];
        if (R_IsNA(val)) {
          if (has_nodata) {
            if (nodata_val < -32768 || nodata_val > 32767)
              error("nodata value out of range for Int16 type");
            tmp[i] = (GInt16) nodata_val;
          } else {
            tmp[i] = 0;
          }
        } else {
          if (val < -32768 || val > 32767)
            error("Raster value out of range for Int16 type");
          tmp[i] = (GInt16) val;
        }
      }
      buffer = tmp;
      break;
    }
    case GDT_UInt32: {
      GUInt32 *tmp = (GUInt32 *) CPLMalloc(sizeof(GUInt32) * n);
      if (tmp == NULL) return NULL;
      for (int i = 0; i < n; i++) {
        double val = src[i];
        if (R_IsNA(val)) {
          if (has_nodata) {
            if (nodata_val < 0 || nodata_val > 4294967295.0)
              error("nodata value out of range for UInt32 type");
            tmp[i] = (GUInt32) nodata_val;
          } else {
            tmp[i] = 0;
          }
        } else {
          if (val < 0 || val > 4294967295.0)
            error("Raster value out of range for UInt32 type");
          tmp[i] = (GUInt32) val;
        }
      }
      buffer = tmp;
      break;
    }
    case GDT_Int32: {
      GInt32 *tmp = (GInt32 *) CPLMalloc(sizeof(GInt32) * n);
      if (tmp == NULL) return NULL;
      for (int i = 0; i < n; i++) {
        double val = src[i];
        if (R_IsNA(val)) {
          if (has_nodata) {
            if (nodata_val < -2147483648.0 || nodata_val > 2147483647.0)
              error("nodata value out of range for Int32 type");
            tmp[i] = (GInt32) nodata_val;
          } else {
            tmp[i] = 0;
          }
        } else {
          if (val < -2147483648.0 || val > 2147483647.0)
            error("Raster value out of range for Int32 type");
          tmp[i] = (GInt32) val;
        }
      }
      buffer = tmp;
      break;
    }
    case GDT_Float32: {
      float *tmp = (float *) CPLMalloc(sizeof(float) * n);
      if (tmp == NULL) return NULL;
      for (int i = 0; i < n; i++) {
        double val = src[i];
        if (R_IsNA(val)) {
          if (has_nodata) {
            tmp[i] = (float) nodata_val;
          } else {
            tmp[i] = (float) NAN;
          }
        } else {
          tmp[i] = (float) val;
        }
      }
      buffer = tmp;
      break;
    }
    case GDT_Float64:
      buffer = (void *) src;
      break;
    default:
      error("Unsupported GDAL data type");
  }

  return buffer;
}

SEXP _rgio_wr(SEXP file, SEXP data, SEXP width, SEXP height,
              SEXP gt, SEXP crs, SEXP datatype, SEXP nodata,
              SEXP co) {
  GDALAllRegister();

  if (TYPEOF(file) != STRSXP || LENGTH(file) != 1) {
    error("'file' must be a single character string");
  }
  if (TYPEOF(data) != REALSXP) {
    error("'data' must be a numeric vector");
  }
  if (TYPEOF(width) != INTSXP || LENGTH(width) != 1) {
    error("'width' must be a single integer");
  }
  if (TYPEOF(height) != INTSXP || LENGTH(height) != 1) {
    error("'height' must be a single integer");
  }
  if (TYPEOF(gt) != REALSXP || LENGTH(gt) != 6) {
    error("'gt' must be a numeric vector of length 6");
  }
  if (TYPEOF(crs) != STRSXP || LENGTH(crs) != 1) {
    error("'crs' must be a single character string");
  }
  if (TYPEOF(datatype) != STRSXP || LENGTH(datatype) != 1) {
    error("'datatype' must be a single character string");
  }
  if (TYPEOF(nodata) != REALSXP || LENGTH(nodata) != 1) {
    error("'nodata' must be a single numeric value (NA allowed)");
  }
  if (TYPEOF(co) != STRSXP && LENGTH(co) != 0) {
    error("'co' must be a character vector");
  }

  const char *filepath = CHAR(STRING_ELT(file, 0));
  const int nXSize = INTEGER(width)[0];
  const int nYSize = INTEGER(height)[0];

  if (nXSize <= 0 || nYSize <= 0) {
    error("'width' and 'height' must be positive");
  }

  const int nPixels = nXSize * nYSize;
  if (LENGTH(data) != nPixels) {
    error("Length of 'data' must equal width * height");
  }

  const char *type_str = CHAR(STRING_ELT(datatype, 0));
  GDALDataType gdal_type = parse_datatype(type_str);
  if (gdal_type == GDT_Unknown) {
    error("Unsupported 'datatype': %s", type_str);
  }

  const double *gt_vals = REAL(gt);
  double nodata_val = REAL(nodata)[0];
  int has_nodata = !R_IsNA(nodata_val);

  char **papszOptions = NULL;
  if (TYPEOF(co) == STRSXP && LENGTH(co) > 0) {
    for (int i = 0; i < LENGTH(co); i++) {
      papszOptions = CSLAddString(papszOptions, CHAR(STRING_ELT(co, i)));
    }
  }

  GDALDriverH driver = GDALGetDriverByName("GTiff");
  if (driver == NULL) {
    if (papszOptions != NULL) CSLDestroy(papszOptions);
    error("GTiff driver is not available");
  }

  GDALDatasetH dataset = GDALCreate(driver, filepath, nXSize, nYSize, 1,
                                    gdal_type, papszOptions);
  if (papszOptions != NULL) CSLDestroy(papszOptions);

  if (dataset == NULL) {
    error("Failed to create GeoTIFF: %s", filepath);
  }

  if (GDALSetGeoTransform(dataset, (double *) gt_vals) != CE_None) {
    GDALClose(dataset);
    error("Failed to set geotransform for %s", filepath);
  }

  const char *crs_str = CHAR(STRING_ELT(crs, 0));
  OGRSpatialReferenceH srs = OSRNewSpatialReference(NULL);
  if (srs == NULL) {
    GDALClose(dataset);
    error("Failed to allocate spatial reference");
  }

  if (OSRSetFromUserInput(srs, crs_str) != OGRERR_NONE) {
    OSRDestroySpatialReference(srs);
    GDALClose(dataset);
    error("Failed to parse CRS: %s", crs_str);
  }

  char *wkt = NULL;
  if (OSRExportToWkt(srs, &wkt) != OGRERR_NONE) {
    OSRDestroySpatialReference(srs);
    GDALClose(dataset);
    error("Failed to export CRS to WKT");
  }

  GDALSetProjection(dataset, wkt);
  CPLFree(wkt);
  OSRDestroySpatialReference(srs);

  GDALRasterBandH band = GDALGetRasterBand(dataset, 1);
  if (band == NULL) {
    GDALClose(dataset);
    error("Failed to access raster band in %s", filepath);
  }

  const double *data_ptr = REAL(data);
  void *buffer = convert_buffer(data_ptr, nPixels, gdal_type,
                                has_nodata, nodata_val);

  if (buffer == NULL && gdal_type != GDT_Float64) {
    GDALClose(dataset);
    error("Failed to allocate buffer for raster data");
  }

  CPLErr err = GDALRasterIO(
      band, GF_Write, 0, 0, nXSize, nYSize,
      buffer, nXSize, nYSize, gdal_type, 0, 0);

  if (gdal_type != GDT_Float64 && buffer != NULL) {
    CPLFree(buffer);
  }

  if (err != CE_None) {
    GDALClose(dataset);
    error("Failed to write raster data to %s", filepath);
  }

  if (has_nodata) {
    GDALSetRasterNoDataValue(band, nodata_val);
  }

  GDALClose(dataset);

  return R_NilValue;
}
