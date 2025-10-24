# ghcog

`ghcog` automates the bookkeeping needed to manage Cloud-Optimized GeoTIFF
assets that live in GitHub Releases. The package is intended to:

- create releases on demand,
- upload or overwrite release assets idempotently,
- resolve signed download URLs without fetching large files, and
- emit GDAL VRT wrappers that reference `/vsicurl/` sources.

## Installation

```r
# install.packages("remotes")
remotes::install_local(".")
```

## Configuration

All helpers accept explicit `repo` and `tag` arguments. To avoid repeating them,
set process-wide defaults once per session:

```r
options(
  ghcog.repo = "rolfsimoes/cogs",
  ghcog.tag  = "cog-test"
)
```

You can also rely on environment variables (`GHCOG_REPO`, `GHCOG_TAG`) when
running batch jobs or CI automation.

## Typical workflow

```r
library(ghcog)

new_githubrelease(
  repo = "rolfsimoes/cogs",
  tag = "cog-test",
  body = "COG release for integration tests"
)

upload_githubassets(
  files = list.files("data/derived", "tif$", full.names = TRUE),
  repo = "rolfsimoes/cogs",
  tag = "cog-test"
)

signed_url <- get_githubasset_url(
  file = "LANDSAT_OLI_2017_corrected.tif",
  repo = "rolfsimoes/cogs",
  tag = "cog-test"
)

vrt_files <- make_vrt(
  repo = "rolfsimoes/cogs",
  tag = "cog-test"
)
```

`make_vrt()` will emit VRT files alongside their corresponding assets; each VRT
references the signed URL through GDAL's `/vsicurl/` driver so downstream tools
stream the original GeoTIFF from GitHub's storage backend without a local copy.

## Testing

The package uses `testthat` with extensive mocking to avoid network and GitHub
side effects. Run the suite with:

```r
testthat::test_dir("tests/testthat")
```
