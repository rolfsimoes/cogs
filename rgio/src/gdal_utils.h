#ifndef RGIO_GDAL_UTILS_H
#define RGIO_GDAL_UTILS_H
#include <gdal.h>
GDALDataType ftype_from_string(const char *dtype);
GDALDatasetH create_raster_dataset(const char *path,
                                   const char *format,
                                   const char *dtype_str,
                                   const double *bbox,
                                   int width, int height,
                                   double resx, double resy,
                                   const char *crs,
                                   int n_bands,
                                   char **co);
void rgio_gdal_init(void);
void rgio_gdal_cleanup(void);
#endif
