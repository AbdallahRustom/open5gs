
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include "user_information.h"

OpenAPI_user_information_t *OpenAPI_user_information_create(
    char *served_gpsi,
    char *served_pei,
    bool is_unauthenticated_flag,
    int unauthenticated_flag,
    OpenAPI_roamer_in_out_t *roamer_in_out
)
{
    OpenAPI_user_information_t *user_information_local_var = ogs_malloc(sizeof(OpenAPI_user_information_t));
    ogs_assert(user_information_local_var);

    user_information_local_var->served_gpsi = served_gpsi;
    user_information_local_var->served_pei = served_pei;
    user_information_local_var->is_unauthenticated_flag = is_unauthenticated_flag;
    user_information_local_var->unauthenticated_flag = unauthenticated_flag;
    user_information_local_var->roamer_in_out = roamer_in_out;

    return user_information_local_var;
}

void OpenAPI_user_information_free(OpenAPI_user_information_t *user_information)
{
    OpenAPI_lnode_t *node = NULL;

    if (NULL == user_information) {
        return;
    }
    if (user_information->served_gpsi) {
        ogs_free(user_information->served_gpsi);
        user_information->served_gpsi = NULL;
    }
    if (user_information->served_pei) {
        ogs_free(user_information->served_pei);
        user_information->served_pei = NULL;
    }
    if (user_information->roamer_in_out) {
        OpenAPI_roamer_in_out_free(user_information->roamer_in_out);
        user_information->roamer_in_out = NULL;
    }
    ogs_free(user_information);
}

cJSON *OpenAPI_user_information_convertToJSON(OpenAPI_user_information_t *user_information)
{
    cJSON *item = NULL;
    OpenAPI_lnode_t *node = NULL;

    if (user_information == NULL) {
        ogs_error("OpenAPI_user_information_convertToJSON() failed [UserInformation]");
        return NULL;
    }

    item = cJSON_CreateObject();
    if (user_information->served_gpsi) {
    if (cJSON_AddStringToObject(item, "servedGPSI", user_information->served_gpsi) == NULL) {
        ogs_error("OpenAPI_user_information_convertToJSON() failed [served_gpsi]");
        goto end;
    }
    }

    if (user_information->served_pei) {
    if (cJSON_AddStringToObject(item, "servedPEI", user_information->served_pei) == NULL) {
        ogs_error("OpenAPI_user_information_convertToJSON() failed [served_pei]");
        goto end;
    }
    }

    if (user_information->is_unauthenticated_flag) {
    if (cJSON_AddBoolToObject(item, "unauthenticatedFlag", user_information->unauthenticated_flag) == NULL) {
        ogs_error("OpenAPI_user_information_convertToJSON() failed [unauthenticated_flag]");
        goto end;
    }
    }

    if (user_information->roamer_in_out) {
    cJSON *roamer_in_out_local_JSON = OpenAPI_roamer_in_out_convertToJSON(user_information->roamer_in_out);
    if (roamer_in_out_local_JSON == NULL) {
        ogs_error("OpenAPI_user_information_convertToJSON() failed [roamer_in_out]");
        goto end;
    }
    cJSON_AddItemToObject(item, "roamerInOut", roamer_in_out_local_JSON);
    if (item->child == NULL) {
        ogs_error("OpenAPI_user_information_convertToJSON() failed [roamer_in_out]");
        goto end;
    }
    }

end:
    return item;
}

OpenAPI_user_information_t *OpenAPI_user_information_parseFromJSON(cJSON *user_informationJSON)
{
    OpenAPI_user_information_t *user_information_local_var = NULL;
    OpenAPI_lnode_t *node = NULL;
    cJSON *served_gpsi = NULL;
    cJSON *served_pei = NULL;
    cJSON *unauthenticated_flag = NULL;
    cJSON *roamer_in_out = NULL;
    OpenAPI_roamer_in_out_t *roamer_in_out_local_nonprim = NULL;
    served_gpsi = cJSON_GetObjectItemCaseSensitive(user_informationJSON, "servedGPSI");
    if (served_gpsi) {
    if (!cJSON_IsString(served_gpsi) && !cJSON_IsNull(served_gpsi)) {
        ogs_error("OpenAPI_user_information_parseFromJSON() failed [served_gpsi]");
        goto end;
    }
    }

    served_pei = cJSON_GetObjectItemCaseSensitive(user_informationJSON, "servedPEI");
    if (served_pei) {
    if (!cJSON_IsString(served_pei) && !cJSON_IsNull(served_pei)) {
        ogs_error("OpenAPI_user_information_parseFromJSON() failed [served_pei]");
        goto end;
    }
    }

    unauthenticated_flag = cJSON_GetObjectItemCaseSensitive(user_informationJSON, "unauthenticatedFlag");
    if (unauthenticated_flag) {
    if (!cJSON_IsBool(unauthenticated_flag)) {
        ogs_error("OpenAPI_user_information_parseFromJSON() failed [unauthenticated_flag]");
        goto end;
    }
    }

    roamer_in_out = cJSON_GetObjectItemCaseSensitive(user_informationJSON, "roamerInOut");
    if (roamer_in_out) {
    roamer_in_out_local_nonprim = OpenAPI_roamer_in_out_parseFromJSON(roamer_in_out);
    if (!roamer_in_out_local_nonprim) {
        ogs_error("OpenAPI_roamer_in_out_parseFromJSON failed [roamer_in_out]");
        goto end;
    }
    }

    user_information_local_var = OpenAPI_user_information_create (
        served_gpsi && !cJSON_IsNull(served_gpsi) ? ogs_strdup(served_gpsi->valuestring) : NULL,
        served_pei && !cJSON_IsNull(served_pei) ? ogs_strdup(served_pei->valuestring) : NULL,
        unauthenticated_flag ? true : false,
        unauthenticated_flag ? unauthenticated_flag->valueint : 0,
        roamer_in_out ? roamer_in_out_local_nonprim : NULL
    );

    return user_information_local_var;
end:
    if (roamer_in_out_local_nonprim) {
        OpenAPI_roamer_in_out_free(roamer_in_out_local_nonprim);
        roamer_in_out_local_nonprim = NULL;
    }
    return NULL;
}

OpenAPI_user_information_t *OpenAPI_user_information_copy(OpenAPI_user_information_t *dst, OpenAPI_user_information_t *src)
{
    cJSON *item = NULL;
    char *content = NULL;

    ogs_assert(src);
    item = OpenAPI_user_information_convertToJSON(src);
    if (!item) {
        ogs_error("OpenAPI_user_information_convertToJSON() failed");
        return NULL;
    }

    content = cJSON_Print(item);
    cJSON_Delete(item);

    if (!content) {
        ogs_error("cJSON_Print() failed");
        return NULL;
    }

    item = cJSON_Parse(content);
    ogs_free(content);
    if (!item) {
        ogs_error("cJSON_Parse() failed");
        return NULL;
    }

    OpenAPI_user_information_free(dst);
    dst = OpenAPI_user_information_parseFromJSON(item);
    cJSON_Delete(item);

    return dst;
}

