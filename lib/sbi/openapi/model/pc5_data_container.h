/*
 * pc5_data_container.h
 *
 * 
 */

#ifndef _OpenAPI_pc5_data_container_H_
#define _OpenAPI_pc5_data_container_H_

#include <string.h>
#include "../external/cJSON.h"
#include "../include/list.h"
#include "../include/keyValuePair.h"
#include "../include/binary.h"
#include "radio_resources_id.h"
#include "user_location.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct OpenAPI_pc5_data_container_s OpenAPI_pc5_data_container_t;
typedef struct OpenAPI_pc5_data_container_s {
    char *local_sequence_number;
    char *change_time;
    bool is_coverage_status;
    int coverage_status;
    struct OpenAPI_user_location_s *user_location_information;
    bool is_data_volume;
    int data_volume;
    char *change_condition;
    struct OpenAPI_radio_resources_id_s *radio_resources_id;
    char *radio_frequency;
    char *p_c5_radio_technology;
} OpenAPI_pc5_data_container_t;

OpenAPI_pc5_data_container_t *OpenAPI_pc5_data_container_create(
    char *local_sequence_number,
    char *change_time,
    bool is_coverage_status,
    int coverage_status,
    OpenAPI_user_location_t *user_location_information,
    bool is_data_volume,
    int data_volume,
    char *change_condition,
    OpenAPI_radio_resources_id_t *radio_resources_id,
    char *radio_frequency,
    char *p_c5_radio_technology
);
void OpenAPI_pc5_data_container_free(OpenAPI_pc5_data_container_t *pc5_data_container);
OpenAPI_pc5_data_container_t *OpenAPI_pc5_data_container_parseFromJSON(cJSON *pc5_data_containerJSON);
cJSON *OpenAPI_pc5_data_container_convertToJSON(OpenAPI_pc5_data_container_t *pc5_data_container);
OpenAPI_pc5_data_container_t *OpenAPI_pc5_data_container_copy(OpenAPI_pc5_data_container_t *dst, OpenAPI_pc5_data_container_t *src);

#ifdef __cplusplus
}
#endif

#endif /* _OpenAPI_pc5_data_container_H_ */

