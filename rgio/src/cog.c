/*
 * translate.c
 * GDALTranslate binding
 */

#include <R.h>
#include <Rinternals.h>
#include <gdal.h>
#include <gdal_utils.h>
#include <cpl_conv.h>
#include <cpl_string.h>
#include <string.h>

/*
 * Entry point for translate function
 *
 * @param src Source raster file path
 * @param dst Destination raster file path
 * @param format Output format string (empty for default)
 * @param resample Resampling method (empty for none)
 * @param nodata Output nodata value (NaN for none)
 * @param options Additional raw GDAL translate options
 * @param co Creation options
 * @param threads Thread count
 * @return Destination path
 */
SEXP _rgio_tr(SEXP src, SEXP dst, SEXP format,
              SEXP resample, SEXP nodata, SEXP options,
              SEXP co, SEXP threads) {

  GDALAllRegister();

  const char *src_file = CHAR(STRING_ELT(src, 0));
  const char *dst_file = CHAR(STRING_ELT(dst, 0));
  const char *format_str = CHAR(STRING_ELT(format, 0));
  const char *resample_str = CHAR(STRING_ELT(resample, 0));
  double nodata_val = REAL(nodata)[0];
  int thread_count = INTEGER(threads)[0];

  GDALDatasetH src_ds = GDALOpen(src_file, GA_ReadOnly);
  if (src_ds == NULL) {
    error("Failed to open source file: %s", src_file);
  }

  /* Configure global threads for translate */
  char *prev_threads = NULL;
  const char *current_threads = CPLGetConfigOption("GDAL_NUM_THREADS", NULL);
  if (current_threads != NULL) {
    prev_threads = CPLStrdup(current_threads);
  }
  if (thread_count > 0) {
    char thread_buf[32];
    snprintf(thread_buf, sizeof(thread_buf), "%d", thread_count);
    CPLSetConfigOption("GDAL_NUM_THREADS", thread_buf);
  } else {
    CPLSetConfigOption("GDAL_NUM_THREADS", "ALL_CPUS");
  }

  char **translate_argv = NULL;

  if (format_str != NULL && strlen(format_str) > 0) {
    translate_argv = CSLAddString(translate_argv, "-of");
    translate_argv = CSLAddString(translate_argv, format_str);
  }

  if (resample_str != NULL && strlen(resample_str) > 0) {
    translate_argv = CSLAddString(translate_argv, "-r");
    translate_argv = CSLAddString(translate_argv, resample_str);
  }

  if (!CPLIsNan(nodata_val)) {
    translate_argv = CSLAddString(translate_argv, "-a_nodata");
    char nodata_buf[64];
    snprintf(nodata_buf, sizeof(nodata_buf), "%.15g", nodata_val);
    translate_argv = CSLAddString(translate_argv, nodata_buf);
  }

  int co_len = length(co);
  for (int i = 0; i < co_len; i++) {
    translate_argv = CSLAddString(translate_argv, "-co");
    translate_argv = CSLAddString(translate_argv, CHAR(STRING_ELT(co, i)));
  }

  int opt_len = length(options);
  for (int i = 0; i < opt_len; i++) {
    translate_argv = CSLAddString(translate_argv, CHAR(STRING_ELT(options, i)));
  }

  GDALTranslateOptions *translate_options = GDALTranslateOptionsNew(translate_argv, NULL);
  CSLDestroy(translate_argv);

  if (translate_options == NULL) {
    GDALClose(src_ds);
    if (prev_threads != NULL) {
      CPLSetConfigOption("GDAL_NUM_THREADS", prev_threads);
      CPLFree(prev_threads);
    } else {
      CPLSetConfigOption("GDAL_NUM_THREADS", NULL);
    }
    error("Failed to create translate options");
  }

  int err_flag = 0;
  GDALDatasetH result_ds = GDALTranslate(dst_file, src_ds, translate_options, &err_flag);

  GDALTranslateOptionsFree(translate_options);
  GDALClose(src_ds);

  if (prev_threads != NULL) {
    CPLSetConfigOption("GDAL_NUM_THREADS", prev_threads);
    CPLFree(prev_threads);
  } else {
    CPLSetConfigOption("GDAL_NUM_THREADS", NULL);
  }

  if (result_ds == NULL || err_flag != 0) {
    error("Translate operation failed for file: %s", src_file);
  }

  GDALClose(result_ds);

  return dst;
}
