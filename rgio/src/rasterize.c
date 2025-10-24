/*
 * rasterize.c
 * Rasterize vector files using GDAL
 */

#include <R.h>
#include <Rinternals.h>
#include <gdal.h>
#include <gdal_alg.h>
#include <ogr_api.h>
#include <ogr_srs_api.h>
#include <cpl_conv.h>
#include <cpl_string.h>
#include <string.h>

/*
 * Entry point for rasterize function
 * 
 * @param files Character vector of input vector file paths
 * @param outdir Output directory
 * @param field Field name to rasterize
 * @param res Resolution (numeric vector of length 2)
 * @param crs Coordinate reference system
 * @param nodata Nodata value
 * @param co GDAL creation options
 * @param threads Number of threads
 * @return Character vector of output file paths
 */
SEXP _rgio_rz(SEXP files, SEXP outdir, SEXP field, SEXP res,
              SEXP crs, SEXP nodata, SEXP co, SEXP threads) {
  
  /* Register GDAL/OGR drivers */
  GDALAllRegister();
  OGRRegisterAll();
  
  /* Extract parameters */
  int n_files = length(files);
  const char *output_dir = CHAR(STRING_ELT(outdir, 0));
  const char *field_name = CHAR(STRING_ELT(field, 0));
  double *resolution = REAL(res);
  double xres = resolution[0];
  double yres = resolution[1];
  const char *target_crs = CHAR(STRING_ELT(crs, 0));
  int nodata_val = INTEGER(nodata)[0];
  int n_threads = INTEGER(threads)[0];
  
  /* Configure threads */
  char *prev_threads = NULL;
  const char *current_threads = CPLGetConfigOption("GDAL_NUM_THREADS", NULL);
  if (current_threads != NULL) {
    prev_threads = CPLStrdup(current_threads);
  }
  if (n_threads > 0) {
    char thread_str[32];
    snprintf(thread_str, sizeof(thread_str), "%d", n_threads);
    CPLSetConfigOption("GDAL_NUM_THREADS", thread_str);
  } else {
    CPLSetConfigOption("GDAL_NUM_THREADS", "ALL_CPUS");
  }
  
  /* Build creation options */
  char **create_opts = NULL;
  for (int i = 0; i < length(co); i++) {
    create_opts = CSLAddString(create_opts, CHAR(STRING_ELT(co, i)));
  }
  
  /* Create output file paths vector */
  SEXP output_paths = PROTECT(allocVector(STRSXP, n_files));
  
  /* Process each input file */
  for (int i = 0; i < n_files; i++) {
    const char *input_file = CHAR(STRING_ELT(files, i));
    
    /* Open vector dataset */
    GDALDatasetH vec_ds = GDALOpenEx(input_file, GDAL_OF_VECTOR, NULL, NULL, NULL);
    if (vec_ds == NULL) {
      CSLDestroy(create_opts);
      if (prev_threads != NULL) {
        CPLSetConfigOption("GDAL_NUM_THREADS", prev_threads);
        CPLFree(prev_threads);
      } else {
        CPLSetConfigOption("GDAL_NUM_THREADS", NULL);
      }
      UNPROTECT(1);
      error("Failed to open vector file: %s", input_file);
    }
    
    /* Get first layer */
    OGRLayerH layer = GDALDatasetGetLayer(vec_ds, 0);
    if (layer == NULL) {
      GDALClose(vec_ds);
      CSLDestroy(create_opts);
      if (prev_threads != NULL) {
        CPLSetConfigOption("GDAL_NUM_THREADS", prev_threads);
        CPLFree(prev_threads);
      } else {
        CPLSetConfigOption("GDAL_NUM_THREADS", NULL);
      }
      UNPROTECT(1);
      error("Failed to get layer from file: %s", input_file);
    }
    
    /* Get layer extent */
    OGREnvelope extent;
    OGRErr ogr_err = OGR_L_GetExtent(layer, &extent, TRUE);
    if (ogr_err != OGRERR_NONE) {
      GDALClose(vec_ds);
      CSLDestroy(create_opts);
      if (prev_threads != NULL) {
        CPLSetConfigOption("GDAL_NUM_THREADS", prev_threads);
        CPLFree(prev_threads);
      } else {
        CPLSetConfigOption("GDAL_NUM_THREADS", NULL);
      }
      UNPROTECT(1);
      error("Failed to get extent from layer in file: %s", input_file);
    }
    
    /* Calculate raster dimensions */
    int width = (int)((extent.MaxX - extent.MinX) / xres + 0.5);
    int height = (int)((extent.MaxY - extent.MinY) / yres + 0.5);
    
    if (width <= 0 || height <= 0) {
      GDALClose(vec_ds);
      CSLDestroy(create_opts);
      UNPROTECT(1);
      error("Invalid raster dimensions for file: %s", input_file);
    }
    
    /* Create output filename */
    const char *base_name = CPLGetBasename(input_file);
    char output_file[4096];
    snprintf(output_file, sizeof(output_file), "%s/%s.tif", output_dir, base_name);
    
    /* Create output raster dataset */
    GDALDriverH gtiff_driver = GDALGetDriverByName("GTiff");
    if (gtiff_driver == NULL) {
      GDALClose(vec_ds);
      CSLDestroy(create_opts);
      if (prev_threads != NULL) {
        CPLSetConfigOption("GDAL_NUM_THREADS", prev_threads);
        CPLFree(prev_threads);
      } else {
        CPLSetConfigOption("GDAL_NUM_THREADS", NULL);
      }
      UNPROTECT(1);
      error("GTiff driver not available");
    }
    
    GDALDatasetH raster_ds = GDALCreate(gtiff_driver, output_file, width, height, 1, GDT_Int32, create_opts);
    if (raster_ds == NULL) {
      GDALClose(vec_ds);
      CSLDestroy(create_opts);
      if (prev_threads != NULL) {
        CPLSetConfigOption("GDAL_NUM_THREADS", prev_threads);
        CPLFree(prev_threads);
      } else {
        CPLSetConfigOption("GDAL_NUM_THREADS", NULL);
      }
      UNPROTECT(1);
      error("Failed to create output raster: %s", output_file);
    }
    
    /* Set geotransform */
    double gt[6];
    gt[0] = extent.MinX;
    gt[1] = xres;
    gt[2] = 0.0;
    gt[3] = extent.MaxY;
    gt[4] = 0.0;
    gt[5] = -yres;
    GDALSetGeoTransform(raster_ds, gt);
    
    /* Set projection */
    GDALSetProjection(raster_ds, target_crs);
    
    /* Get raster band and set nodata */
    GDALRasterBandH band = GDALGetRasterBand(raster_ds, 1);
    GDALSetRasterNoDataValue(band, (double)nodata_val);
    GDALFillRaster(band, (double)nodata_val, 0.0);
    
    /* Get field index */
    OGRFeatureDefnH layer_defn = OGR_L_GetLayerDefn(layer);
    int field_idx = OGR_FD_GetFieldIndex(layer_defn, field_name);
    
    /* Set up rasterize options */
    char **rasterize_opts = NULL;
    if (field_idx >= 0) {
      char attr_opt[256];
      snprintf(attr_opt, sizeof(attr_opt), "ATTRIBUTE=%s", field_name);
      rasterize_opts = CSLAddString(rasterize_opts, attr_opt);
    } else {
      /* If field not found, burn value 1 */
      rasterize_opts = CSLAddString(rasterize_opts, "BURN_VALUE=1");
    }
    
    /* Add ALL_TOUCHED option for better coverage */
    rasterize_opts = CSLAddString(rasterize_opts, "ALL_TOUCHED=FALSE");
    
    /* Rasterize */
    int band_list[1] = {1};
    double burn_values[1] = {1.0};
    
    OGRLayerH layers[1] = {layer};
    CPLErr err;
    
    if (field_idx >= 0) {
      err = GDALRasterizeLayers(raster_ds, 1, band_list, 1, (OGRLayerH*)layers,
                                NULL, NULL, NULL, rasterize_opts, NULL, NULL);
    } else {
      err = GDALRasterizeLayers(raster_ds, 1, band_list, 1, (OGRLayerH*)layers,
                                NULL, NULL, burn_values, rasterize_opts, NULL, NULL);
    }
    
    CSLDestroy(rasterize_opts);
    
    if (err != CE_None) {
      GDALClose(raster_ds);
      GDALClose(vec_ds);
      CSLDestroy(create_opts);
      if (prev_threads != NULL) {
        CPLSetConfigOption("GDAL_NUM_THREADS", prev_threads);
      } else {
        CPLSetConfigOption("GDAL_NUM_THREADS", NULL);
      }
      UNPROTECT(1);
      error("Rasterization failed for file: %s", input_file);
    }
    
    /* Close datasets */
    GDALClose(raster_ds);
    GDALClose(vec_ds);
    
    /* Store output path */
    SET_STRING_ELT(output_paths, i, mkChar(output_file));
  }
  
  /* Clean up */
  CSLDestroy(create_opts);
  
  if (prev_threads != NULL) {
    CPLSetConfigOption("GDAL_NUM_THREADS", prev_threads);
    CPLFree(prev_threads);
  } else {
    CPLSetConfigOption("GDAL_NUM_THREADS", NULL);
  }
  
  UNPROTECT(1);
  return output_paths;
}
