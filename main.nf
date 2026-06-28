#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

/*
 * Convert an XCMS-style feature intensity matrix and feature definition table
 * into the peak table layout expected by LAMP.
 */

workflow {
    if (!params.values) {
        error 'Missing required parameter: --values <feature_values.csv>'
    }

    if (!params.features) {
        error 'Missing required parameter: --features <feature_definitions.csv>'
    }

    values_ch = Channel.fromPath(params.values, checkIfExists: true)
    features_ch = Channel.fromPath(params.features, checkIfExists: true)
    converter_script_ch = Channel.fromPath("${projectDir}/scripts/convert_xcms_to_lamp.R", checkIfExists: true)

    CONVERT_XCMS_TO_LAMP(values_ch, features_ch, converter_script_ch)

    if (!params.skip_lamp) {
        RUN_LAMP_ANNOTATION(CONVERT_XCMS_TO_LAMP.out.lamp_input)
    }
}

process CONVERT_XCMS_TO_LAMP {
    tag "${values.simpleName}"

    publishDir params.outdir, mode: 'copy'

    input:
    path values
    path features
    path converter_script

    output:
    path params.output_name, emit: lamp_input

    script:
    """
    ${params.rscript_bin} ${converter_script} \\
      --values=${values} \\
      --features=${features} \\
      --output=${params.output_name} \\
      --sep=${params.sep} \\
      --mz-col=${params.mz_col} \\
      --rt-col=${params.rt_col}
    """
}

process RUN_LAMP_ANNOTATION {
    tag "${lamp_input.simpleName}"

    publishDir params.outdir, mode: 'copy'

    input:
    path lamp_input

    output:
    path params.lamp_db_out, emit: database, optional: true
    path params.lamp_sr_out, emit: single_row_results
    path params.lamp_mr_out, emit: multi_row_results, optional: true

    script:
    def positive_flag = params.lamp_positive ? '--positive' : ''
    def cal_mass_flag = params.lamp_cal_mass ? '--cal-mass' : ''
    def save_db_flag = params.lamp_save_db ? '--save-db' : ''
    def save_mr_flag = params.lamp_save_mr ? '--save-mr' : ''
    def ref_args = params.lamp_ref_path ? "--ref-path ${params.lamp_ref_path} --ref-sep ${params.lamp_ref_sep}" : ''
    def add_args = params.lamp_add_path ? "--add-path ${params.lamp_add_path} --add-sep ${params.lamp_add_sep}" : ''

    """
    ${params.lamp_bin} cli \\
      --input-data ${lamp_input} \\
      --col-idx "${params.lamp_col_idx}" \\
      --input-sep ${params.sep} \\
      --ion-mode ${params.lamp_ion_mode} \\
      --thres-rt ${params.lamp_thres_rt} \\
      --thres-corr ${params.lamp_thres_corr} \\
      --thres-pval ${params.lamp_thres_pval} \\
      --method ${params.lamp_method} \\
      ${positive_flag} \\
      --ppm ${params.lamp_ppm} \\
      ${cal_mass_flag} \\
      ${ref_args} \\
      ${add_args} \\
      ${save_db_flag} \\
      ${save_mr_flag} \\
      --db-out ${params.lamp_db_out} \\
      --sr-out ${params.lamp_sr_out} \\
      --sr-sep ${params.lamp_sr_sep} \\
      --mr-out ${params.lamp_mr_out} \\
      --mr-sep ${params.lamp_mr_sep}
    """
}
