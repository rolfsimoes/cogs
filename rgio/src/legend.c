/*
 * legend.c
 * Write color table and category names to rasters
 */

#include <R.h>
#include <Rinternals.h>
#include <gdal.h>
#include <cpl_conv.h>
#include <cpl_string.h>

/*
 * Entry point for legend function
 * 
 * @param file Target file path (GTiff or VRT)
 * @param values Pixel values for color table entries
 * @param colors_rgba RGBA color matrix (n x 4)
 * @param labels Category labels
 * @return NULL (invisibly)
 */
SEXP _rgio_lg(SEXP file, SEXP values, SEXP colors_rgba, SEXP labels) {
  
  /* Register GDAL drivers */
  GDALAllRegister();
  
  /* Extract parameters */
  const char *file_path = CHAR(STRING_ELT(file, 0));
  int n_entries = length(values);
  int *value_indices = INTEGER(values);
  double *colors = REAL(colors_rgba);
  int has_labels = (length(labels) > 0);
  
  /* Open dataset in update mode */
  GDALDatasetH dataset = GDALOpen(file_path, GA_Update);
  if (dataset == NULL) {
    error("Failed to open file for update: %s", file_path);
  }
  
  /* Get first raster band */
  GDALRasterBandH band = GDALGetRasterBand(dataset, 1);
  if (band == NULL) {
    GDALClose(dataset);
    error("Failed to get raster band from file: %s", file_path);
  }
  
  /* Create color table */
  GDALColorTableH color_table = GDALCreateColorTable(GPI_RGB);
  if (color_table == NULL) {
    GDALClose(dataset);
    error("Failed to create color table");
  }
  
  /* Add color entries */
  for (int i = 0; i < n_entries; i++) {
    GDALColorEntry color_entry;
    
    /* Extract RGBA values from matrix (stored column-major) */
    color_entry.c1 = (short)colors[i];                    /* R */
    color_entry.c2 = (short)colors[i + n_entries];        /* G */
    color_entry.c3 = (short)colors[i + 2 * n_entries];    /* B */
    color_entry.c4 = (short)colors[i + 3 * n_entries];    /* A */
    
    /* Set color entry at the specified index */
    GDALSetColorEntry(color_table, value_indices[i], &color_entry);
  }
  
  /* Set color table to band */
  CPLErr err = GDALSetRasterColorTable(band, color_table);
  if (err != CE_None) {
    GDALDestroyColorTable(color_table);
    GDALClose(dataset);
    error("Failed to set color table for file: %s", file_path);
  }
  
  /* Set category names if provided */
  if (has_labels) {
    /* Build category names array */
    char **category_names = (char **)CPLCalloc(n_entries + 1, sizeof(char *));
    
    for (int i = 0; i < n_entries; i++) {
      category_names[i] = CPLStrdup(CHAR(STRING_ELT(labels, i)));
    }
    category_names[n_entries] = NULL;
    
    /* Set category names */
    err = GDALSetRasterCategoryNames(band, category_names);
    
    /* Free category names */
    CSLDestroy(category_names);
    
    if (err != CE_None) {
      GDALDestroyColorTable(color_table);
      GDALClose(dataset);
      error("Failed to set category names for file: %s", file_path);
    }
  }
  
  /* Set palette interpretation */
  GDALSetRasterColorInterpretation(band, GCI_PaletteIndex);
  
  /* Clean up */
  GDALDestroyColorTable(color_table);
  GDALClose(dataset);
  
  return R_NilValue;
}

