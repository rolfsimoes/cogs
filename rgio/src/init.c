/*
 * init.c
 * Registration of native routines for the rgio package
 */

#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>

/* Forward declarations of C entry points */
extern SEXP _rgio_rz(SEXP files, SEXP outdir, SEXP value, SEXP field,
                     SEXP res, SEXP crs, SEXP nodata, SEXP dtype,
                     SEXP format, SEXP ro, SEXP co, SEXP threads);
extern SEXP _rgio_wp(SEXP src, SEXP dst, SEXP tr, SEXP crs,
                     SEXP resample, SEXP dstnodata, SEXP wo,
                     SEXP co, SEXP threads, SEXP format, SEXP overwrite);
extern SEXP _rgio_rd(SEXP src, SEXP bbox, SEXP width, SEXP height,
                     SEXP crs, SEXP resample, SEXP nodata,
                     SEXP threads, SEXP warp_opts);
extern SEXP _rgio_lg(SEXP file, SEXP values, SEXP colors_rgba, SEXP labels);
extern SEXP _rgio_vf(SEXP src, SEXP bbox, SEXP width, SEXP height,
                     SEXP crs, SEXP opts);
extern SEXP _rgio_vrt_palette_get(SEXP file);
extern SEXP _rgio_vrt_palette_set(SEXP file, SEXP values, SEXP colors, SEXP nrows);
extern SEXP _rgio_vrt_legend_get(SEXP file);
extern SEXP _rgio_vrt_legend_set(SEXP file, SEXP values, SEXP labels);
extern SEXP _rgio_tr(SEXP src, SEXP dst, SEXP format,
                     SEXP resample, SEXP nodata, SEXP options,
                     SEXP co, SEXP threads);
extern SEXP _rgio_wr(SEXP file, SEXP data, SEXP width, SEXP height,
                     SEXP gt, SEXP crs, SEXP datatype, SEXP nodata,
                     SEXP co);
extern SEXP _rgio_pal(SEXP file, SEXP indices);
extern SEXP _rgio_overviews(SEXP path, SEXP levels, SEXP resample,
                            SEXP external, SEXP threads);
extern SEXP _rgio_info(SEXP path);
extern SEXP _rgio_vec(SEXP src, SEXP dst, SEXP format, SEXP band,
                      SEXP field, SEXP connectedness, SEXP mask, SEXP co);
extern SEXP _rgio_gdal_capabilities(SEXP format);

/* Registration table */
static const R_CallMethodDef CallEntries[] = {
  {"_rgio_rz", (DL_FUNC) &_rgio_rz, 12},
  {"_rgio_wp", (DL_FUNC) &_rgio_wp, 11},
  {"_rgio_rd", (DL_FUNC) &_rgio_rd, 9},
  {"_rgio_lg", (DL_FUNC) &_rgio_lg, 4},
  {"_rgio_vf", (DL_FUNC) &_rgio_vf, 6},
  {"_rgio_vrt_palette_get", (DL_FUNC) &_rgio_vrt_palette_get, 1},
  {"_rgio_vrt_palette_set", (DL_FUNC) &_rgio_vrt_palette_set, 4},
  {"_rgio_vrt_legend_get", (DL_FUNC) &_rgio_vrt_legend_get, 1},
  {"_rgio_vrt_legend_set", (DL_FUNC) &_rgio_vrt_legend_set, 3},
  {"_rgio_tr", (DL_FUNC) &_rgio_tr, 8},
  {"_rgio_wr", (DL_FUNC) &_rgio_wr, 9},
  {"_rgio_pal", (DL_FUNC) &_rgio_pal, 2},
  {"_rgio_overviews", (DL_FUNC) &_rgio_overviews, 5},
  {"_rgio_info", (DL_FUNC) &_rgio_info, 1},
  {"_rgio_vec", (DL_FUNC) &_rgio_vec, 8},
  {"_rgio_gdal_capabilities", (DL_FUNC) &_rgio_gdal_capabilities, 1},
  {NULL, NULL, 0}
};

/* Forward declaration of GDAL utilities */
extern void rgio_gdal_init(void);
extern void rgio_gdal_cleanup(void);

/* Package initialization */
void R_init_rgio(DllInfo *dll) {
  R_registerRoutines(dll, NULL, CallEntries, NULL, NULL);
  R_useDynamicSymbols(dll, FALSE);

  /* Initialize GDAL */
  rgio_gdal_init();
}

/* Package finalization */
void R_unload_rgio(DllInfo *dll) {
  /* Cleanup GDAL */
  rgio_gdal_cleanup();
}
