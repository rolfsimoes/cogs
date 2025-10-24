/*
 * gdal_utils.cpp
 * Shared GDAL utility functions
 */

#include <gdal.h>
#include <cpl_conv.h>

extern "C" {

/*
 * Initialize GDAL - call once at package load
 * This is a utility function that can be called from R_init_rgio
 */
void rgio_gdal_init(void) {
  GDALAllRegister();
  CPLSetConfigOption("GDAL_NUM_THREADS", "ALL_CPUS");
  CPLSetConfigOption("GDAL_CACHEMAX", "256");
}

/*
 * Cleanup GDAL - call at package unload
 */
void rgio_gdal_cleanup(void) {
  GDALDestroyDriverManager();
}

} /* extern "C" */

