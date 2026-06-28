# nf-annotate-lcms

Nextflow workflow for preparing LC-MS feature tables for LAMP and running LAMP annotation.

The workflow takes XCMS-style CSV outputs, converts them into the peak-list table expected by LAMP, and optionally runs LAMP to produce metabolite annotation outputs.

## Workflow

1. Convert feature values and feature definitions into a LAMP-compatible input table.
2. Run `lamp cli` on the converted table, unless `--skip_lamp true` is set.
3. Publish the converted input table and LAMP result files to `--outdir`.

## Requirements

For local runs:

- Nextflow
- R
- LAMP command line tool, available as `lamp`

For HPC runs:

- Nextflow
- SLURM
- Apptainer
- A LAMP Apptainer image, or the included definition file at `containers/apptianer.def`

## Inputs

The workflow requires two CSV files:

- `--values`: feature intensity matrix. The first column is used as the feature name, and all remaining columns are treated as sample intensity columns.
- `--features`: feature definition table. This must have the same number of rows as `--values` and contain m/z and retention time columns.

By default, the feature definition columns are:

- m/z: `mzmed`
- retention time: `rtmed`

Override these with `--mz_col` and `--rt_col` if your files use different column names.

## Outputs

Default output files:

```text
lamp_input.tsv
lamp_annotations.tsv
lamp_annotations_multirow.tsv
lamp_results.db
```

`lamp_input.tsv` has the LAMP peak-list layout:

```text
name    mz    rt    sample_1    sample_2    ...
```

The LAMP column index for this generated file is:

```text
1,2,3,4
```

## Run Test Data

From a local checkout:

```bash
nextflow run . -profile local,test
```

From GitHub:

```bash
nextflow run wilsontom/nf-annotate-lcms -profile local,test
```

To only test the CSV conversion step:

```bash
nextflow run . -profile local,test --skip_lamp true
```

## Run Locally

From a local checkout:

```bash
nextflow run . -profile local \
  --values path/to/feature_values.csv \
  --features path/to/feature_definitions.csv \
  --outdir results/lamp
```

From GitHub:

```bash
nextflow run wilsontom/nf-annotate-lcms -profile local \
  --values path/to/feature_values.csv \
  --features path/to/feature_definitions.csv \
  --outdir results/lamp
```

## Run On HPC

The `hpc` profile submits jobs to SLURM and runs processes with Apptainer:

```bash
nextflow run wilsontom/nf-annotate-lcms -profile hpc \
  --values path/to/feature_values.csv \
  --features path/to/feature_definitions.csv \
  --outdir results/lamp \
  --apptainer_image /path/to/lamp.sif \
  --slurm_queue queue_name
```

If your site requires a SLURM account or extra submit options:

```bash
nextflow run wilsontom/nf-annotate-lcms -profile hpc \
  --values path/to/feature_values.csv \
  --features path/to/feature_definitions.csv \
  --apptainer_image /path/to/lamp.sif \
  --slurm_queue queue_name \
  --slurm_account account_name \
  --slurm_cluster_options "--constraint=..."
```

## Key Parameters

| Parameter | Default | Description |
| --- | --- | --- |
| `--values` | required | Feature intensity CSV. |
| `--features` | required | Feature definitions CSV. |
| `--outdir` | `results` | Output directory. |
| `--output_name` | `lamp_input.tsv` | Converted LAMP input file name. |
| `--sep` | `tab` | Output separator for converted table, `tab` or `comma`. |
| `--mz_col` | `mzmed` | m/z column in the feature definitions table. |
| `--rt_col` | `rtmed` | Retention time column in the feature definitions table. |
| `--rscript_bin` | `Rscript` | Rscript executable. The `hpc` profile defaults to `/opt/conda/bin/Rscript`. |
| `--lamp_bin` | `lamp` | LAMP executable. The `hpc` profile defaults to `/opt/conda/bin/lamp`. |
| `--skip_lamp` | `false` | Stop after creating the LAMP input table. |
| `--lamp_ion_mode` | `neg` | LAMP ion mode, `pos` or `neg`. |
| `--lamp_thres_rt` | `1.0` | Retention time threshold. |
| `--lamp_thres_corr` | `0.5` | Correlation threshold. |
| `--lamp_thres_pval` | `0.05` | Correlation p-value threshold. |
| `--lamp_method` | `pearson` | Correlation method, `pearson` or `spearman`. |
| `--lamp_ppm` | `5.0` | Mass tolerance in ppm. |
| `--lamp_ref_path` | unset | Optional LAMP reference file. |
| `--lamp_add_path` | unset | Optional LAMP adduct library file. |
| `--apptainer_image` | bundled definition file | Apptainer image or definition file for containerized runs. |
| `--slurm_queue` | unset | SLURM partition or queue for the `hpc` profile. |
| `--slurm_account` | unset | Optional SLURM account. |
| `--slurm_cluster_options` | unset | Optional extra SLURM submit options. |

## Profiles

| Profile | Purpose |
| --- | --- |
| `local` | Run processes on the local machine. |
| `test` | Use CSV files in `testing/`. Combine with `local` or `hpc`. |
| `hpc` | Submit processes to SLURM and run with Apptainer. |
| `apptainer` | Run locally with Apptainer. |
| `singularity` | Run locally with Singularity. |

## Notes

- LAMP can take several minutes or longer depending on the number of features and samples.
- When running from GitHub, Nextflow downloads the workflow code to its asset cache. Input paths are still resolved relative to the directory where you launch the command.
- The HPC profile assumes the Apptainer image contains both `/opt/conda/bin/Rscript` and `/opt/conda/bin/lamp`. The bundled definition file installs both. If you use a different image, override `--rscript_bin` and `--lamp_bin` or rebuild the image with R and LAMP installed.
- Use `--skip_lamp true` when you only need to generate the LAMP input table.
- If the number of rows differs between `--values` and `--features`, the conversion step fails before LAMP runs.
