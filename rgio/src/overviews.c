/*
 * overviews.c
 * Build raster overviews using GDAL
 */

#include <R.h>
#include <Rinternals.h>
#include <gdal.h>
#include <cpl_conv.h>
#include <cpl_string.h>
#include <string.h>

SEXP _rgio_overviews(SEXP path, SEXP levels, SEXP resample,
                     SEXP external, SEXP threads) {
  const char *dataset_path = CHAR(STRING_ELT(path, 0));
  const char *resample_method = CHAR(STRING_ELT(resample, 0));
  int external_flag = LOGICAL(external)[0];
  int thread_count = INTEGER(threads)[0];

  GDALAllRegister();

  GDALDatasetH ds = GDALOpen(dataset_path, GA_Update);
  if (ds == NULL) {
    error("Failed to open dataset for overview creation: %s", dataset_path);
  }

  char *prev_threads = NULL;
  const char *current_threads = CPLGetConfigOption("GDAL_NUM_THREADS", NULL);
  if (current_threads != NULL) {
    prev_threads = CPLStrdup(current_threads);
  }
  if (thread_count > 0) {
    char buf[32];
    snprintf(buf, sizeof(buf), "%d", thread_count);
    CPLSetConfigOption("GDAL_NUM_THREADS", buf);
  } else {
    CPLSetConfigOption("GDAL_NUM_THREADS", "ALL_CPUS");
  }

  int n_levels = LENGTH(levels);
  int *overview_list = NULL;

  if (n_levels > 0) {
    overview_list = (int *) CPLCalloc(n_levels, sizeof(int));
    for (int i = 0; i < n_levels; i++) {
      overview_list[i] = INTEGER(levels)[i];
    }
  } else {
    int width = GDALGetRasterXSize(ds);
    int height = GDALGetRasterYSize(ds);
    int max_dim = width > height ? width : height;
    int level = 2;
    int capacity = 8;
    overview_list = (int *) CPLCalloc(capacity, sizeof(int));
    n_levels = 0;
    while (level < max_dim) {
      if (n_levels == capacity) {
        capacity *= 2;
        overview_list = (int *) CPLRealloc(overview_list, capacity * sizeof(int));
      }
      overview_list[n_levels++] = level;
      if (max_dim / level <= 256) {
        break;
      }
      level *= 2;
    }
    if (n_levels == 0) {
      overview_list[n_levels++] = 2;
    }
  }

  if (external_flag) {
    const char *ovr_tmp = CPLResetExtension(dataset_path, "ovr");
    char *ovr_copy = CPLStrdup(ovr_tmp);
    GDALSetMetadataItem(ds, "OVERVIEW_FILE", ovr_copy, "OVERVIEWS");
    CPLFree(ovr_copy);
  }

  CPLErr err = GDALBuildOverviews(ds, resample_method, n_levels, overview_list,
                                  0, NULL, NULL, NULL);

  CPLFree(overview_list);

  if (prev_threads != NULL) {
    CPLSetConfigOption("GDAL_NUM_THREADS", prev_threads);
    CPLFree(prev_threads);
  } else {
    CPLSetConfigOption("GDAL_NUM_THREADS", NULL);
  }

  if (err != CE_None) {
    GDALClose(ds);
    error("Failed to build overviews for %s", dataset_path);
  }

  GDALClose(ds);
  return path;
}
