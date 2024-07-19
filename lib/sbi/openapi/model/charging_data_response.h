/*
 * charging_data_response.h
 *
 * 
 */

#ifndef _OpenAPI_charging_data_response_H_
#define _OpenAPI_charging_data_response_H_

#include <string.h>
#include "../external/cJSON.h"
#include "../include/list.h"
#include "../include/keyValuePair.h"
#include "../include/binary.h"
#include "invocation_result.h"
#include "location_reporting_charging_information.h"
#include "multiple_unit_information.h"
#include "pdu_session_charging_information.h"
#include "roaming_qbc_information.h"
#include "session_failover.h"
#include "trigger.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct OpenAPI_charging_data_response_s OpenAPI_charging_data_response_t;
typedef struct OpenAPI_charging_data_response_s {
    char *invocation_time_stamp;
    int invocation_sequence_number;
    struct OpenAPI_invocation_result_s *invocation_result;
    struct OpenAPI_session_failover_s *session_failover;
    char *supported_features;
    OpenAPI_list_t *multiple_unit_information;
    OpenAPI_list_t *triggers;
    struct OpenAPI_pdu_session_charging_information_s *p_du_session_charging_information;
    struct OpenAPI_roaming_qbc_information_s *roaming_qbc_information;
    struct OpenAPI_location_reporting_charging_information_s *location_reporting_charging_information;
} OpenAPI_charging_data_response_t;

OpenAPI_charging_data_response_t *OpenAPI_charging_data_response_create(
    char *invocation_time_stamp,
    int invocation_sequence_number,
    OpenAPI_invocation_result_t *invocation_result,
    OpenAPI_session_failover_t *session_failover,
    char *supported_features,
    OpenAPI_list_t *multiple_unit_information,
    OpenAPI_list_t *triggers,
    OpenAPI_pdu_session_charging_information_t *p_du_session_charging_information,
    OpenAPI_roaming_qbc_information_t *roaming_qbc_information,
    OpenAPI_location_reporting_charging_information_t *location_reporting_charging_information
);
void OpenAPI_charging_data_response_free(OpenAPI_charging_data_response_t *charging_data_response);
OpenAPI_charging_data_response_t *OpenAPI_charging_data_response_parseFromJSON(cJSON *charging_data_responseJSON);
cJSON *OpenAPI_charging_data_response_convertToJSON(OpenAPI_charging_data_response_t *charging_data_response);
OpenAPI_charging_data_response_t *OpenAPI_charging_data_response_copy(OpenAPI_charging_data_response_t *dst, OpenAPI_charging_data_response_t *src);

#ifdef __cplusplus
}
#endif

#endif /* _OpenAPI_charging_data_response_H_ */

