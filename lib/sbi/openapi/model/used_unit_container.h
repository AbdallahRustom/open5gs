/*
 * used_unit_container.h
 *
 * 
 */

#ifndef _OpenAPI_used_unit_container_H_
#define _OpenAPI_used_unit_container_H_

#include <string.h>
#include "../external/cJSON.h"
#include "../include/list.h"
#include "../include/keyValuePair.h"
#include "../include/binary.h"
#include "nspa_container_information.h"
#include "pc5_container_information.h"
#include "pdu_container_information.h"
#include "quota_management_indicator.h"
#include "trigger.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct OpenAPI_used_unit_container_s OpenAPI_used_unit_container_t;
typedef struct OpenAPI_used_unit_container_s {
    bool is_service_id;
    int service_id;
    char* quota_management_indicator;
    OpenAPI_list_t *triggers;
    char *trigger_timestamp;
    bool is_time;
    int time;
    bool is_total_volume;
    int total_volume;
    bool is_uplink_volume;
    int uplink_volume;
    bool is_downlink_volume;
    int downlink_volume;
    bool is_service_specific_units;
    int service_specific_units;
    OpenAPI_list_t *event_time_stamps;
    int local_sequence_number;
    struct OpenAPI_pdu_container_information_s *p_du_container_information;
    struct OpenAPI_nspa_container_information_s *n_spa_container_information;
    struct OpenAPI_pc5_container_information_s *p_c5_container_information;
} OpenAPI_used_unit_container_t;

OpenAPI_used_unit_container_t *OpenAPI_used_unit_container_create(
    bool is_service_id,
    int service_id,
    char* quota_management_indicator,
    OpenAPI_list_t *triggers,
    char *trigger_timestamp,
    bool is_time,
    int time,
    bool is_total_volume,
    int total_volume,
    bool is_uplink_volume,
    int uplink_volume,
    bool is_downlink_volume,
    int downlink_volume,
    bool is_service_specific_units,
    int service_specific_units,
    OpenAPI_list_t *event_time_stamps,
    int local_sequence_number,
    OpenAPI_pdu_container_information_t *p_du_container_information,
    OpenAPI_nspa_container_information_t *n_spa_container_information,
    OpenAPI_pc5_container_information_t *p_c5_container_information
);
void OpenAPI_used_unit_container_free(OpenAPI_used_unit_container_t *used_unit_container);
OpenAPI_used_unit_container_t *OpenAPI_used_unit_container_parseFromJSON(cJSON *used_unit_containerJSON);
cJSON *OpenAPI_used_unit_container_convertToJSON(OpenAPI_used_unit_container_t *used_unit_container);
OpenAPI_used_unit_container_t *OpenAPI_used_unit_container_copy(OpenAPI_used_unit_container_t *dst, OpenAPI_used_unit_container_t *src);

#ifdef __cplusplus
}
#endif

#endif /* _OpenAPI_used_unit_container_H_ */

