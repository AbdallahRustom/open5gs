/*
 * invocation_result.h
 *
 * 
 */

#ifndef _OpenAPI_invocation_result_H_
#define _OpenAPI_invocation_result_H_

#include <string.h>
#include "../external/cJSON.h"
#include "../include/list.h"
#include "../include/keyValuePair.h"
#include "../include/binary.h"
#include "failure_handling.h"
#include "problem_details.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct OpenAPI_invocation_result_s OpenAPI_invocation_result_t;
typedef struct OpenAPI_invocation_result_s {
    struct OpenAPI_problem_details_s *error;
    struct OpenAPI_failure_handling_s *failure_handling;
} OpenAPI_invocation_result_t;

OpenAPI_invocation_result_t *OpenAPI_invocation_result_create(
    OpenAPI_problem_details_t *error,
    OpenAPI_failure_handling_t *failure_handling
);
void OpenAPI_invocation_result_free(OpenAPI_invocation_result_t *invocation_result);
OpenAPI_invocation_result_t *OpenAPI_invocation_result_parseFromJSON(cJSON *invocation_resultJSON);
cJSON *OpenAPI_invocation_result_convertToJSON(OpenAPI_invocation_result_t *invocation_result);
OpenAPI_invocation_result_t *OpenAPI_invocation_result_copy(OpenAPI_invocation_result_t *dst, OpenAPI_invocation_result_t *src);

#ifdef __cplusplus
}
#endif

#endif /* _OpenAPI_invocation_result_H_ */

