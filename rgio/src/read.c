/*
 * read.c
 * Read rasters to bounding box grid using GDAL
 */

#include <R.h>
#include <Rinternals.h>
#include <gdal.h>
#include "gdal_utils.h"
#include <gdal_alg.h>
#include <gdalwarper.h>
#include <cpl_conv.h>
#include <cpl_string.h>

/*
 * Entry point for read function
 * 
 * @param src Source raster file paths
 * @param bbox Bounding box (xmin, ymin, xmax, ymax)
 * @param width Grid width in pixels
 * @param height Grid height in pixels
 * @param crs Coordinate reference system
 * @param resample Resampling method
 * @param nodata Nodata value
 * @param threads Number of threads
 * @param warp_opts Additional warp options
 * @return Data frame with band columns and spatial attributes
 */
SEXP _rgio_rd(SEXP src, SEXP bbox, SEXP width, SEXP height,
              SEXP crs, SEXP resample, SEXP nodata,
              SEXP threads, SEXP warp_opts) {
  
  /* Register GDAL drivers */
  GDALAllRegister();
  
  /* Extract parameters */
  int n_sources = length(src);
  int grid_width = INTEGER(width)[0];
  int grid_height = INTEGER(height)[0];
  double *bbox_vals = REAL(bbox);
  double xmin = bbox_vals[0];
  double ymin = bbox_vals[1];
  double xmax = bbox_vals[2];
  double ymax = bbox_vals[3];
  const char *target_crs = CHAR(STRING_ELT(crs, 0));
  const char *resample_method = CHAR(STRING_ELT(resample, 0));
  double nodata_val = REAL(nodata)[0];
  int n_threads = INTEGER(threads)[0];
  
  /* Calculate geotransform */
  double gt[6];
  gt[0] = xmin;                                    /* top left x */
  gt[1] = (xmax - xmin) / grid_width;             /* w-e pixel resolution */
  gt[2] = 0.0;                                     /* rotation, 0 if image is "north up" */
  gt[3] = ymax;                                    /* top left y */
  gt[4] = 0.0;                                     /* rotation, 0 if image is "north up" */
  gt[5] = -(ymax - ymin) / grid_height;           /* n-s pixel resolution (negative) */
  
  /* Determine resampling algorithm */
  GDALResampleAlg resample_alg = GRA_NearestNeighbour;
  if (strcmp(resample_method, "bilinear") == 0) {
    resample_alg = GRA_Bilinear;
  } else if (strcmp(resample_method, "cubic") == 0) {
    resample_alg = GRA_Cubic;
  } else if (strcmp(resample_method, "cubicspline") == 0) {
    resample_alg = GRA_CubicSpline;
  } else if (strcmp(resample_method, "lanczos") == 0) {
    resample_alg = GRA_Lanczos;
  } else if (strcmp(resample_method, "average") == 0) {
    resample_alg = GRA_Average;
  } else if (strcmp(resample_method, "mode") == 0) {
    resample_alg = GRA_Mode;
  } else if (strcmp(resample_method, "min") == 0) {
    resample_alg = GRA_Min;
  } else if (strcmp(resample_method, "max") == 0) {
    resample_alg = GRA_Max;
  } else if (strcmp(resample_method, "med") == 0) {
    resample_alg = GRA_Med;
  } else if (strcmp(resample_method, "sum") == 0) {
    resample_alg = GRA_Sum;
  } else if (strcmp(resample_method, "rms") == 0) {
    resample_alg = GRA_RMS;
  } else if (strcmp(resample_method, "q1") == 0) {
    resample_alg = GRA_Q1;
  } else if (strcmp(resample_method, "q3") == 0) {
    resample_alg = GRA_Q3;
  }
  
  /* Create result data frame */
  int n_pixels = grid_width * grid_height;
  SEXP result = PROTECT(allocVector(VECSXP, n_sources));
  SEXP names = PROTECT(allocVector(STRSXP, n_sources));
  
  /* Process each source file */
  for (int i = 0; i < n_sources; i++) {
    const char *src_file = CHAR(STRING_ELT(src, i));
    
    /* Open source dataset */
    GDALDatasetH src_ds = GDALOpen(src_file, GA_ReadOnly);
    if (src_ds == NULL) {
      UNPROTECT(2);
      error("Failed to open source file: %s", src_file);
    }
    
    /* Create in-memory target dataset */
    GDALDatasetH dst_ds = create_raster_dataset(
      "",
      "MEM",
      "Float64",
      NULL,
      grid_width,
      grid_height,
      0.0,
      0.0,
      target_crs,
      1,
      NULL
    );
    if (dst_ds == NULL) {
      GDALClose(src_ds);
      UNPROTECT(2);
      error("Failed to create in-memory dataset");
    }
    
    /* Set target geotransform and projection */
    GDALSetGeoTransform(dst_ds, gt);
    
    /* Get target band and set nodata */
    GDALRasterBandH dst_band = GDALGetRasterBand(dst_ds, 1);
    GDALSetRasterNoDataValue(dst_band, nodata_val);
    
    /* Set up warp options */
    GDALWarpOptions *warp_opts_ptr = GDALCreateWarpOptions();
    if (warp_opts_ptr == NULL) {
      GDALClose(dst_ds);
      GDALClose(src_ds);
      UNPROTECT(2);
      error("Failed to allocate warp options");
    }
    warp_opts_ptr->hSrcDS = src_ds;
    warp_opts_ptr->hDstDS = dst_ds;
    warp_opts_ptr->nBandCount = 1;
    warp_opts_ptr->panSrcBands = (int *) CPLMalloc(sizeof(int));
    warp_opts_ptr->panDstBands = (int *) CPLMalloc(sizeof(int));
    warp_opts_ptr->panSrcBands[0] = 1;
    warp_opts_ptr->panDstBands[0] = 1;
    warp_opts_ptr->eResampleAlg = resample_alg;
    warp_opts_ptr->dfWarpMemoryLimit = 0.0; /* Use default */

    int has_threads_opt = 0;
    int n_warp_opts = LENGTH(warp_opts);
    for (int j = 0; j < n_warp_opts; j++) {
      const char *opt = CHAR(STRING_ELT(warp_opts, j));
      if (opt == NULL) continue;
      warp_opts_ptr->papszWarpOptions = CSLAddString(warp_opts_ptr->papszWarpOptions, opt);
      if (EQUALN(opt, "NUM_THREADS=", 12)) {
        has_threads_opt = 1;
      }
    }

    if (!has_threads_opt) {
      if (n_threads > 0) {
        char thread_str[32];
        snprintf(thread_str, sizeof(thread_str), "%d", n_threads);
        warp_opts_ptr->papszWarpOptions = CSLSetNameValue(
          warp_opts_ptr->papszWarpOptions, "NUM_THREADS", thread_str);
      } else {
        warp_opts_ptr->papszWarpOptions = CSLSetNameValue(
          warp_opts_ptr->papszWarpOptions, "NUM_THREADS", "ALL_CPUS");
      }
    }
    
    /* Create transformer */
    warp_opts_ptr->pTransformerArg = 
      GDALCreateGenImgProjTransformer(src_ds, GDALGetProjectionRef(src_ds),
                                      dst_ds, target_crs,
                                      FALSE, 0.0, 1);
    
    if (warp_opts_ptr->pTransformerArg == NULL) {
      GDALDestroyWarpOptions(warp_opts_ptr);
      GDALClose(dst_ds);
      GDALClose(src_ds);
      UNPROTECT(2);
      error("Failed to create coordinate transformer");
    }
    
    warp_opts_ptr->pfnTransformer = GDALGenImgProjTransform;
    
    /* Execute warp operation */
    GDALWarpOperationH warp_op = GDALCreateWarpOperation(warp_opts_ptr);
    if (warp_op == NULL) {
      GDALDestroyGenImgProjTransformer(warp_opts_ptr->pTransformerArg);
      GDALDestroyWarpOptions(warp_opts_ptr);
      GDALClose(dst_ds);
      GDALClose(src_ds);
      UNPROTECT(2);
      error("Failed to initialize warp operation");
    }
    
    CPLErr err = GDALChunkAndWarpImage(warp_op, 0, 0, grid_width, grid_height);
    
    if (err != CE_None) {
      GDALDestroyWarpOperation(warp_op);
      GDALDestroyGenImgProjTransformer(warp_opts_ptr->pTransformerArg);
      GDALDestroyWarpOptions(warp_opts_ptr);
      GDALClose(dst_ds);
      GDALClose(src_ds);
      UNPROTECT(2);
      error("Warp operation failed for file: %s", src_file);
    }
    
    /* Read pixel data into R vector */
    SEXP band_data = PROTECT(allocVector(REALSXP, n_pixels));
    double *data_ptr = REAL(band_data);
    
    err = GDALRasterIO(dst_band, GF_Read, 0, 0, grid_width, grid_height,
                       data_ptr, grid_width, grid_height, GDT_Float64,
                       0, 0);
    
    if (err != CE_None) {
      GDALDestroyWarpOperation(warp_op);
      GDALDestroyGenImgProjTransformer(warp_opts_ptr->pTransformerArg);
      GDALDestroyWarpOptions(warp_opts_ptr);
      GDALClose(dst_ds);
      GDALClose(src_ds);
      UNPROTECT(3);
      error("Failed to read raster data from file: %s", src_file);
    }
    
    /* Add to result list */
    SET_VECTOR_ELT(result, i, band_data);
    
    /* Set band name */
    char band_name[32];
    snprintf(band_name, sizeof(band_name), "b%d", i + 1);
    SET_STRING_ELT(names, i, mkChar(band_name));
    
    /* Clean up */
    GDALDestroyWarpOperation(warp_op);
    GDALDestroyGenImgProjTransformer(warp_opts_ptr->pTransformerArg);
    GDALDestroyWarpOptions(warp_opts_ptr);
    GDALClose(dst_ds);
    GDALClose(src_ds);
    
    UNPROTECT(1); /* band_data */
  }
  
  /* Set names attribute */
  setAttrib(result, R_NamesSymbol, names);
  
  /* Set class to data.frame */
  setAttrib(result, R_ClassSymbol, mkString("data.frame"));
  
  /* Set row names */
  SEXP row_names = PROTECT(allocVector(INTSXP, 2));
  INTEGER(row_names)[0] = NA_INTEGER;
  INTEGER(row_names)[1] = -n_pixels;
  setAttrib(result, R_RowNamesSymbol, row_names);
  
  /* Add spatial metadata attributes */
  SEXP gt_attr = PROTECT(allocVector(REALSXP, 6));
  double *gt_vals = REAL(gt_attr);
  for (int i = 0; i < 6; i++) {
    gt_vals[i] = gt[i];
  }
  setAttrib(result, install("gt"), gt_attr);
  
  setAttrib(result, install("width"), width);
  setAttrib(result, install("height"), height);
  setAttrib(result, install("crs"), crs);
  setAttrib(result, install("nodata"), nodata);
  
  UNPROTECT(4); /* result, names, row_names, gt_attr */
  return result;
}
