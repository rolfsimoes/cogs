/*
 * warp.c
 * Warp and mosaic rasters using GDAL
 */

#include <R.h>
#include <Rinternals.h>
#include <gdal.h>
#include <gdal_utils.h>
#include <cpl_conv.h>
#include <cpl_string.h>
#include <string.h>

/*
 * Entry point for warp function
 * 
 * @param src Source raster file paths
 * @param dst Destination file path
 * @param tr Target resolution
 * @param crs Target CRS
 * @param resample Resampling method
 * @param dstnodata Destination nodata value
 * @param opts GDAL warp options
 * @param filetype Output file type
 * @param overwrite Overwrite flag
 * @return Destination file path
 */
SEXP _rgio_wp(SEXP src, SEXP dst, SEXP tr, SEXP crs,
              SEXP resample, SEXP dstnodata, SEXP wo,
              SEXP co, SEXP threads, SEXP format, SEXP overwrite) {
  
  /* Register GDAL drivers */
  GDALAllRegister();
  
  /* Extract parameters */
  int n_sources = length(src);
  const char *dst_file = CHAR(STRING_ELT(dst, 0));
  double *resolution = REAL(tr);
  const char *target_crs = CHAR(STRING_ELT(crs, 0));
  const char *resample_method = CHAR(STRING_ELT(resample, 0));
  double nodata_val = REAL(dstnodata)[0];
  int thread_count = INTEGER(threads)[0];
  const char *format_str = CHAR(STRING_ELT(format, 0));
  int do_overwrite = LOGICAL(overwrite)[0];
  
  /* Build source file list */
  char **src_files = (char **)CPLCalloc(n_sources + 1, sizeof(char *));
  for (int i = 0; i < n_sources; i++) {
    src_files[i] = CPLStrdup(CHAR(STRING_ELT(src, i)));
  }
  src_files[n_sources] = NULL;
  
  /* Build warp options array */
  char **warp_argv = NULL;
  warp_argv = CSLAddString(warp_argv, "-multi");

  /* Creation options */
  int co_len = length(co);
  for (int i = 0; i < co_len; i++) {
    warp_argv = CSLAddString(warp_argv, "-co");
    warp_argv = CSLAddString(warp_argv, CHAR(STRING_ELT(co, i)));
  }

  /* Warp options */
  int wo_len = length(wo);
  int has_threads_opt = 0;
  for (int i = 0; i < wo_len; i++) {
    const char *opt = CHAR(STRING_ELT(wo, i));
    if (opt == NULL) continue;
    warp_argv = CSLAddString(warp_argv, "-wo");
    warp_argv = CSLAddString(warp_argv, opt);
    if (EQUALN(opt, "NUM_THREADS=", 12)) {
      has_threads_opt = 1;
    }
  }
  if (!has_threads_opt) {
    warp_argv = CSLAddString(warp_argv, "-wo");
    if (thread_count > 0) {
      char thread_opt[64];
      snprintf(thread_opt, sizeof(thread_opt), "NUM_THREADS=%d", thread_count);
      warp_argv = CSLAddString(warp_argv, thread_opt);
    } else {
      warp_argv = CSLAddString(warp_argv, "NUM_THREADS=ALL_CPUS");
    }
  }
  
  /* Add target resolution */
  warp_argv = CSLAddString(warp_argv, "-tr");
  char res_x[64], res_y[64];
  snprintf(res_x, sizeof(res_x), "%.15g", resolution[0]);
  snprintf(res_y, sizeof(res_y), "%.15g", resolution[1]);
  warp_argv = CSLAddString(warp_argv, res_x);
  warp_argv = CSLAddString(warp_argv, res_y);
  
  /* Add target CRS */
  warp_argv = CSLAddString(warp_argv, "-t_srs");
  warp_argv = CSLAddString(warp_argv, target_crs);
  
  /* Add resampling method */
  warp_argv = CSLAddString(warp_argv, "-r");
  warp_argv = CSLAddString(warp_argv, resample_method);
  
  /* Add destination nodata */
  if (!CPLIsNan(nodata_val)) {
    warp_argv = CSLAddString(warp_argv, "-dstnodata");
    char nodata_str[64];
    snprintf(nodata_str, sizeof(nodata_str), "%.15g", nodata_val);
    warp_argv = CSLAddString(warp_argv, nodata_str);
  }
  
  /* Add overwrite flag if needed */
  if (do_overwrite) {
    warp_argv = CSLAddString(warp_argv, "-overwrite");
  }
  
  /* Determine output format */
  if (format_str != NULL && strlen(format_str) > 0) {
    warp_argv = CSLAddString(warp_argv, "-of");
    warp_argv = CSLAddString(warp_argv, format_str);
  }
  
  /* Create warp options */
  GDALWarpAppOptions *warp_options = GDALWarpAppOptionsNew(warp_argv, NULL);
  CSLDestroy(warp_argv);
  
  if (warp_options == NULL) {
    CSLDestroy(src_files);
    error("Failed to create warp options");
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
      GDALWarpAppOptionsFree(warp_options);
      CSLDestroy(src_files);
      error("Failed to open source file: %s", src_files[i]);
    }
  }
  
  /* Execute warp */
  int err_flag = 0;
  GDALDatasetH result_ds = GDALWarp(dst_file, NULL, n_sources, src_datasets, 
                                     warp_options, &err_flag);
  
  /* Clean up */
  for (int i = 0; i < n_sources; i++) {
    GDALClose(src_datasets[i]);
  }
  CPLFree(src_datasets);
  GDALWarpAppOptionsFree(warp_options);
  CSLDestroy(src_files);
  
  if (result_ds == NULL || err_flag != 0) {
    error("Warp operation failed");
  }
  
  GDALClose(result_ds);
  
  return dst;
}
