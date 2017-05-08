#ifndef __OPENCL_VERSION__
#include "header.cl"
#endif

__kernel void TEMPLATE(DecodeBBoxesCORNER, Dtype)(const int nthreads,
          __global const Dtype* loc_data, __global const Dtype* prior_data,
          const int variance_encoded_in_target,
          const int num_priors, const int share_location,
          const int num_loc_classes, const int background_label_id,
          const int clip_bbox, __global Dtype* bbox_data) {

  for (int index = get_global_id(0); index < nthreads; index += get_global_size(0)) {
    const int i = index % 4;
    const int c = (index / 4) % num_loc_classes;
    const int d = (index / 4 / num_loc_classes) % num_priors;
    if (!share_location && c == background_label_id) {
      // Ignore background class if not share_location.
      return;
    }
    const int pi = d * 4;
    const int vi = pi + num_priors * 4;
    if (variance_encoded_in_target) {
      // variance is encoded in target, we simply need to add the offset
      // predictions.
      bbox_data[index] = prior_data[pi + i] + loc_data[index];
    } else {
      // variance is encoded in bbox, we need to scale the offset accordingly.
      bbox_data[index] =
        prior_data[pi + i] + loc_data[index] * prior_data[vi + i];
    }
    if (clip_bbox) {
      bbox_data[index] = max(min(bbox_data[index], (Dtype)1.), (Dtype)0.);
    }
  }
}

__kernel void TEMPLATE(DecodeBBoxesCENTER_SIZE, Dtype)(const int nthreads,
          __global const Dtype* loc_data, __global const Dtype* prior_data,
          const int variance_encoded_in_target,
          const int num_priors, const int share_location,
          const int num_loc_classes, const int background_label_id,
          const int clip_bbox, __global Dtype* bbox_data) {

  for (int index = get_global_id(0); index < nthreads; index += get_global_size(0)) {
    const int i = index % 4;
    const int c = (index / 4) % num_loc_classes;
    const int d = (index / 4 / num_loc_classes) % num_priors;
    if (!share_location && c == background_label_id) {
      // Ignore background class if not share_location.
      return;
    }
    const int pi = d * 4;
    const int vi = pi + num_priors * 4;
    const Dtype p_xmin = prior_data[pi];
    const Dtype p_ymin = prior_data[pi + 1];
    const Dtype p_xmax = prior_data[pi + 2];
    const Dtype p_ymax = prior_data[pi + 3];
    const Dtype prior_width = p_xmax - p_xmin;
    const Dtype prior_height = p_ymax - p_ymin;
    const Dtype prior_center_x = (p_xmin + p_xmax) / 2.;
    const Dtype prior_center_y = (p_ymin + p_ymax) / 2.;

    const Dtype xmin = loc_data[index - i];
    const Dtype ymin = loc_data[index - i + 1];
    const Dtype xmax = loc_data[index - i + 2];
    const Dtype ymax = loc_data[index - i + 3];

    Dtype decode_bbox_center_x, decode_bbox_center_y;
    Dtype decode_bbox_width, decode_bbox_height;
    if (variance_encoded_in_target) {
      // variance is encoded in target, we simply need to retore the offset
      // predictions.
      decode_bbox_center_x = xmin * prior_width + prior_center_x;
      decode_bbox_center_y = ymin * prior_height + prior_center_y;
      decode_bbox_width = exp(xmax) * prior_width;
      decode_bbox_height = exp(ymax) * prior_height;
    } else {
      // variance is encoded in bbox, we need to scale the offset accordingly.
      decode_bbox_center_x =
        prior_data[vi] * xmin * prior_width + prior_center_x;
      decode_bbox_center_y =
        prior_data[vi + 1] * ymin * prior_height + prior_center_y;
      decode_bbox_width =
        exp(prior_data[vi + 2] * xmax) * prior_width;
      decode_bbox_height =
        exp(prior_data[vi + 3] * ymax) * prior_height;
    }

    switch (i) {
      case 0:
        bbox_data[index] = decode_bbox_center_x - decode_bbox_width / 2.;
        break;
      case 1:
        bbox_data[index] = decode_bbox_center_y - decode_bbox_height / 2.;
        break;
      case 2:
        bbox_data[index] = decode_bbox_center_x + decode_bbox_width / 2.;
        break;
      case 3:
        bbox_data[index] = decode_bbox_center_y + decode_bbox_height / 2.;
        break;
    }
    if (clip_bbox) {
      bbox_data[index] = max(min(bbox_data[index], (Dtype)1.), (Dtype)0.);
    }
  }
}

__kernel void TEMPLATE(DecodeBBoxesCORNER_SIZE, Dtype)(const int nthreads,
          __global const Dtype* loc_data, __global const Dtype* prior_data,
          const int variance_encoded_in_target,
          const int num_priors, const int share_location,
          const int num_loc_classes, const int background_label_id,
          const int clip_bbox, __global Dtype* bbox_data) {

  for (int index = get_global_id(0); index < nthreads; index += get_global_size(0)) {
    const int i = index % 4;
    const int c = (index / 4) % num_loc_classes;
    const int d = (index / 4 / num_loc_classes) % num_priors;
    if (!share_location && c == background_label_id) {
      // Ignore background class if not share_location.
      return;
    }
    const int pi = d * 4;
    const int vi = pi + num_priors * 4;
    const Dtype p_xmin = prior_data[pi];
    const Dtype p_ymin = prior_data[pi + 1];
    const Dtype p_xmax = prior_data[pi + 2];
    const Dtype p_ymax = prior_data[pi + 3];
    const Dtype prior_width = p_xmax - p_xmin;
    const Dtype prior_height = p_ymax - p_ymin;
    Dtype p_size;
    if (i == 0 || i == 2) {
      p_size = prior_width;
    } else {
      p_size = prior_height;
    }
    if (variance_encoded_in_target) {
      // variance is encoded in target, we simply need to add the offset
      // predictions.
      bbox_data[index] = prior_data[pi + i] + loc_data[index] * p_size;
    } else {
      // variance is encoded in bbox, we need to scale the offset accordingly.
      bbox_data[index] =
      prior_data[pi + i] + loc_data[index] * prior_data[vi + i] * p_size;
    }
    if (clip_bbox) {
      bbox_data[index] = max(min(bbox_data[index], (Dtype)1.), (Dtype)0.);
    }
  }
}




