/*
 * gdal_utils.c
 * Shared GDAL utility functions for rgio
 */

#include <gdal.h>
#include <ogr_srs_api.h>
#include <cpl_conv.h>
#include <cpl_string.h>
#include <math.h>
#include <string.h>
#include "gdal_utils.h"

/*
 * Initialize GDAL - call once at package load (R_init_rgio)
 */
void rgio_gdal_init(void) {
  GDALAllRegister();
  CPLSetConfigOption("GDAL_NUM_THREADS", "ALL_CPUS");
  CPLSetConfigOption("GDAL_CACHEMAX", "256"); /* MB */
}

/*
 * Cleanup GDAL - call at package unload (R_unload_rgio)
 */
void rgio_gdal_cleanup(void) {
  GDALDestroyDriverManager();
}

/* -------------------------------------------------------------------------- */
/*  dtype_from_string()                                                       */
/* -------------------------------------------------------------------------- */
/*
 * Map string to GDALDataType
 *
 * Accepts typical GDAL data type names:
 * "Byte", "UInt16", "Int16", "UInt32", "Int32",
 * "Float32", "Float64", "CInt16", "CInt32", "CFloat32", "CFloat64"
 *
 * Returns GDT_Int32 as fallback.
 */
GDALDataType ftype_from_string(const char *dtype) {
  if (dtype == NULL) return GDT_Int32;

  if (EQUAL(dtype, "Byte")) return GDT_Byte;
  if (EQUAL(dtype, "UInt16")) return GDT_UInt16;
  if (EQUAL(dtype, "Int16")) return GDT_Int16;
  if (EQUAL(dtype, "UInt32")) return GDT_UInt32;
  if (EQUAL(dtype, "Int32")) return GDT_Int32;
  if (EQUAL(dtype, "Float32")) return GDT_Float32;
  if (EQUAL(dtype, "Float64")) return GDT_Float64;
  if (EQUAL(dtype, "CInt16")) return GDT_CInt16;
  if (EQUAL(dtype, "CInt32")) return GDT_CInt32;
  if (EQUAL(dtype, "CFloat32")) return GDT_CFloat32;
  if (EQUAL(dtype, "CFloat64")) return GDT_CFloat64;

  CPLDebug("rgio", "Unknown dtype '%s', defaulting to Int32.", dtype);
  return GDT_Int32;
}

/* -------------------------------------------------------------------------- */
/*  create_raster_dataset()                                                   */
/* -------------------------------------------------------------------------- */
/*
 * Create a GDAL raster dataset with specified format, data type, and geometry.
 *
 * Parameters:
 *  path       - Output file path
 *  format     - Driver name (e.g., "GTiff", "COG", "MEM", "VRT")
 *  dtype_str  - Data type string (see ftype_from_string)
 *  bbox       - [xmin, ymin, xmax, ymax] (length 4)
 *  width      - Raster width (ignored if resx/resy > 0)
 *  height     - Raster height (ignored if resx/resy > 0)
 *  resx,resy  - Pixel sizes (if >0, override width/height)
 *  crs        - CRS string ("EPSG:4326", WKT, etc.)
 *  n_bands    - Number of bands
 *  co         - Creation options (NULL-terminated string list)
 *
 * Returns:
 *  GDALDatasetH - handle to open writable dataset
 */
GDALDatasetH create_raster_dataset(const char *path,
                                   const char *format,
                                   const char *dtype_str,
                                   const double *bbox,
                                   int width,
                                   int height,
                                   double resx,
                                   double resy,
                                   const char *crs,
                                   int n_bands,
                                   char **co)
{
  if (path == NULL || format == NULL) {
    CPLError(CE_Failure, CPLE_AppDefined,
             "Invalid raster creation arguments (path or format missing).");
    return NULL;
  }

  if (resx > 0 && resy > 0 && bbox != NULL) {
    width  = (int)ceil((bbox[2] - bbox[0]) / resx);
    height = (int)ceil((bbox[3] - bbox[1]) / resy);
  }

  if (width <= 0 || height <= 0) {
    CPLError(CE_Failure, CPLE_AppDefined,
             "Invalid raster dimensions (%d x %d).", width, height);
    return NULL;
  }

  GDALDriverH driver = GDALGetDriverByName(format);
  if (driver == NULL) {
    CPLError(CE_Failure, CPLE_AppDefined,
             "Driver not found: %s", format);
    return NULL;
  }
  GDALDataType gdt = ftype_from_string(dtype_str);
  GDALDatasetH ds = GDALCreate(driver, path, width, height, n_bands, gdt, co);
  if (ds == NULL) {
    CPLError(CE_Failure, CPLE_AppDefined,
             "Failed to create raster: %s", path);
    return NULL;
  }

  /* Geotransform */
  if (bbox != NULL) {
    double xmin = bbox[0], ymin = bbox[1], xmax = bbox[2], ymax = bbox[3];
    double gt[6];
    if (resx > 0 && resy > 0) {
      gt[0] = xmin;  gt[1] = resx;  gt[2] = 0;
      gt[3] = ymax;  gt[4] = 0;     gt[5] = -resy;
    } else {
      gt[0] = xmin;  gt[1] = (xmax - xmin) / width;  gt[2] = 0;
      gt[3] = ymax;  gt[4] = 0;     gt[5] = -(ymax - ymin) / height;
    }
    GDALSetGeoTransform(ds, gt);
  }

  /* Projection */
  if (crs && strlen(crs) > 0) {
    OGRSpatialReferenceH srs = OSRNewSpatialReference(NULL);
    if (OSRSetFromUserInput(srs, crs) == OGRERR_NONE) {
      char *wkt = NULL;
      OSRExportToWkt(srs, &wkt);
      GDALSetProjection(ds, wkt);
      CPLFree(wkt);
    } else {
      CPLError(CE_Warning, CPLE_AppDefined, "Failed to parse CRS: %s", crs);
    }
    OSRDestroySpatialReference(srs);
  }

  return ds;
}

