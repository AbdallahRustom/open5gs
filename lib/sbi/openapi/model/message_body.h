/*
 * message_body.h
 *
 * 
 */

#ifndef _OpenAPI_message_body_H_
#define _OpenAPI_message_body_H_

#include <string.h>
#include "../external/cJSON.h"
#include "../include/list.h"
#include "../include/keyValuePair.h"
#include "../include/binary.h"
#include "originator_party_type.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct OpenAPI_message_body_s OpenAPI_message_body_t;
typedef struct OpenAPI_message_body_s {
    char *content_type;
    int content_length;
    char *content_disposition;
    struct OpenAPI_originator_party_type_s *originator;
} OpenAPI_message_body_t;

OpenAPI_message_body_t *OpenAPI_message_body_create(
    char *content_type,
    int content_length,
    char *content_disposition,
    OpenAPI_originator_party_type_t *originator
);
void OpenAPI_message_body_free(OpenAPI_message_body_t *message_body);
OpenAPI_message_body_t *OpenAPI_message_body_parseFromJSON(cJSON *message_bodyJSON);
cJSON *OpenAPI_message_body_convertToJSON(OpenAPI_message_body_t *message_body);
OpenAPI_message_body_t *OpenAPI_message_body_copy(OpenAPI_message_body_t *dst, OpenAPI_message_body_t *src);

#ifdef __cplusplus
}
#endif

#endif /* _OpenAPI_message_body_H_ */

