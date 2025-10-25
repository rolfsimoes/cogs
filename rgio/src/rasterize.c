/*
 * rasterize.c
 * Rasterize vector files using GDAL
 *
 * Architecture:
 *   R front-end -> .Call("_rgio_rz", ...) -> this C entrypoint -> internal helpers
 *
 * Remaining TODOs:
 * - loop is still serial; parallelization can be added later at higher level
 */

#include <R.h>
#include <Rinternals.h>
#include <gdal.h>
#include <gdal_alg.h>
#include <ogr_api.h>
#include <cpl_conv.h>
#include <cpl_string.h>
#include <math.h>
#include <string.h>

#include "gdal_utils.h"

/*
 * _rgio_rz
 * Rasterize vector layers (e.g. shapefiles, GeoJSON) into rasters (GTiff or COG)
 *
 * Parameters from R:
 *  files   - character vector of vector file paths
 *  outdir  - output directory for rasters
 *  value   - numeric constant burn value (used if field missing)
 *  field   - character string, name of attribute to burn (optional)
 *  res     - numeric vector of length 2 (xres, yres)
 *  crs     - character string (CRS, e.g. "EPSG:4326")
 *  nodata  - integer or numeric nodata value
 *  dtype   - character string (GDAL type, e.g. "Byte", "UInt16", "Float32")
 *  format  - character string (output driver, e.g. "GTiff" or "COG")
 *  ro      - character vector (rasterize options)
 *  co      - character vector (creation options)
 *  threads - integer number of threads (currently unused)
 *
 * Returns:
 *  Character vector of output file paths
 */
SEXP _rgio_rz(SEXP files, SEXP outdir, SEXP value, SEXP field,
              SEXP res, SEXP crs, SEXP nodata, SEXP dtype,
              SEXP format, SEXP ro, SEXP co, SEXP threads)
{
  GDALAllRegister();
  OGRRegisterAll();

  int n_files = Rf_length(files);
  const char *output_dir = CHAR(STRING_ELT(outdir, 0));
  const char *field_name = CHAR(STRING_ELT(field, 0));
  const char *target_crs = CHAR(STRING_ELT(crs, 0));
  const char *dtype_str  = CHAR(STRING_ELT(dtype, 0));
  const char *format_str = CHAR(STRING_ELT(format, 0));
  double *resolution = REAL(res);
  double xres = resolution[0];
  double yres = resolution[1];
  int nodata_val = INTEGER(nodata)[0];
  double burn_val = (value != R_NilValue) ? REAL(value)[0] : 1.0;

  /* Build creation options */
  char **create_opts = NULL;
  for (int i = 0; i < Rf_length(co); i++)
    create_opts = CSLAddString(create_opts, CHAR(STRING_ELT(co, i)));

  SEXP output_paths = PROTECT(Rf_allocVector(STRSXP, n_files));

  for (int i = 0; i < n_files; i++) {
    const char *input_file = CHAR(STRING_ELT(files, i));

    GDALDatasetH vec_ds = GDALOpenEx(input_file, GDAL_OF_VECTOR, NULL, NULL, NULL);
    if (vec_ds == NULL) {
      CSLDestroy(create_opts);
      error("Failed to open vector file: %s", input_file);
    }

    OGRLayerH layer = GDALDatasetGetLayer(vec_ds, 0);
    if (layer == NULL) {
      GDALClose(vec_ds);
      CSLDestroy(create_opts);
      error("No layer found in file: %s", input_file);
    }

    /* Compute extent */
    OGREnvelope extent;
    if (OGR_L_GetExtent(layer, &extent, TRUE) != OGRERR_NONE) {
      GDALClose(vec_ds);
      CSLDestroy(create_opts);
      error("Failed to get extent for file: %s", input_file);
    }

    double bbox[4] = {extent.MinX, extent.MinY, extent.MaxX, extent.MaxY};
    const char *base_name = CPLGetBasename(input_file);
    char output_file[4096];
    snprintf(output_file, sizeof(output_file), "%s/%s.tif", output_dir, base_name);

    /* Create output raster */
    GDALDatasetH raster_ds = create_raster_dataset(
      output_file,
      format_str,
      dtype_str,
      bbox,
      0, 0, xres, yres,
      target_crs,
      1,
      create_opts
    );
    if (raster_ds == NULL) {
      GDALClose(vec_ds);
      CSLDestroy(create_opts);
      error("Failed to create output raster: %s", output_file);
    }

    /* Initialize raster */
    GDALRasterBandH band = GDALGetRasterBand(raster_ds, 1);
    GDALSetRasterNoDataValue(band, (double)nodata_val);
    GDALFillRaster(band, (double)nodata_val, 0.0);

    /* Check if field exists */
    int field_exists = 0;
    OGRFeatureDefnH defn = OGR_L_GetLayerDefn(layer);
    if (OGR_FD_GetFieldIndex(defn, field_name) >= 0) {
      field_exists = 1;
    }

    /* Rasterize options */
    char **rasterize_opts = NULL;
    if (field_exists) {
      char attr_opt[256];
      snprintf(attr_opt, sizeof(attr_opt), "ATTRIBUTE=%s", field_name);
      rasterize_opts = CSLAddString(rasterize_opts, attr_opt);
    }
    for (int j = 0; j < Rf_length(ro); j++) {
      rasterize_opts = CSLAddString(rasterize_opts, CHAR(STRING_ELT(ro, j)));
    }

    double burn_values[1] = {burn_val};
    int band_list[1] = {1};
    OGRLayerH layers[1] = {layer};

    /* Perform rasterization */
    CPLErr err;
    if (field_exists) {
      err = GDALRasterizeLayers(raster_ds, 1, band_list, 1, layers,
                                NULL, NULL, NULL, rasterize_opts, NULL, NULL);
    } else {
      err = GDALRasterizeLayers(raster_ds, 1, band_list, 1, layers,
                                NULL, NULL, burn_values, NULL, NULL, NULL);
    }

    CSLDestroy(rasterize_opts);

    if (err != CE_None) {
      GDALClose(raster_ds);
      GDALClose(vec_ds);
      CSLDestroy(create_opts);
      error("Rasterization failed for %s", input_file);
    }

    GDALSetMetadataItem(raster_ds, "AREA_OR_POINT", "Area", NULL);
    GDALClose(raster_ds);
    GDALClose(vec_ds);

    SET_STRING_ELT(output_paths, i, Rf_mkChar(output_file));
  }

  CSLDestroy(create_opts);
  UNPROTECT(1);
  return output_paths;
}
