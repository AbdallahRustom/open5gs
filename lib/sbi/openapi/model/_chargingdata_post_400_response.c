
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include "_chargingdata_post_400_response.h"

OpenAPI__chargingdata_post_400_response_t *OpenAPI__chargingdata_post_400_response_create(
    char *type,
    char *title,
    bool is_status,
    int status,
    char *detail,
    char *instance,
    char *cause,
    OpenAPI_list_t *invalid_params,
    char *supported_features,
    OpenAPI_access_token_err_t *access_token_error,
    OpenAPI_access_token_req_t *access_token_request,
    char *nrf_id,
    OpenAPI_invocation_result_t *invocation_result
)
{
    OpenAPI__chargingdata_post_400_response_t *_chargingdata_post_400_response_local_var = ogs_malloc(sizeof(OpenAPI__chargingdata_post_400_response_t));
    ogs_assert(_chargingdata_post_400_response_local_var);

    _chargingdata_post_400_response_local_var->type = type;
    _chargingdata_post_400_response_local_var->title = title;
    _chargingdata_post_400_response_local_var->is_status = is_status;
    _chargingdata_post_400_response_local_var->status = status;
    _chargingdata_post_400_response_local_var->detail = detail;
    _chargingdata_post_400_response_local_var->instance = instance;
    _chargingdata_post_400_response_local_var->cause = cause;
    _chargingdata_post_400_response_local_var->invalid_params = invalid_params;
    _chargingdata_post_400_response_local_var->supported_features = supported_features;
    _chargingdata_post_400_response_local_var->access_token_error = access_token_error;
    _chargingdata_post_400_response_local_var->access_token_request = access_token_request;
    _chargingdata_post_400_response_local_var->nrf_id = nrf_id;
    _chargingdata_post_400_response_local_var->invocation_result = invocation_result;

    return _chargingdata_post_400_response_local_var;
}

void OpenAPI__chargingdata_post_400_response_free(OpenAPI__chargingdata_post_400_response_t *_chargingdata_post_400_response)
{
    OpenAPI_lnode_t *node = NULL;

    if (NULL == _chargingdata_post_400_response) {
        return;
    }
    if (_chargingdata_post_400_response->type) {
        ogs_free(_chargingdata_post_400_response->type);
        _chargingdata_post_400_response->type = NULL;
    }
    if (_chargingdata_post_400_response->title) {
        ogs_free(_chargingdata_post_400_response->title);
        _chargingdata_post_400_response->title = NULL;
    }
    if (_chargingdata_post_400_response->detail) {
        ogs_free(_chargingdata_post_400_response->detail);
        _chargingdata_post_400_response->detail = NULL;
    }
    if (_chargingdata_post_400_response->instance) {
        ogs_free(_chargingdata_post_400_response->instance);
        _chargingdata_post_400_response->instance = NULL;
    }
    if (_chargingdata_post_400_response->cause) {
        ogs_free(_chargingdata_post_400_response->cause);
        _chargingdata_post_400_response->cause = NULL;
    }
    if (_chargingdata_post_400_response->invalid_params) {
        OpenAPI_list_for_each(_chargingdata_post_400_response->invalid_params, node) {
            OpenAPI_invalid_param_free(node->data);
        }
        OpenAPI_list_free(_chargingdata_post_400_response->invalid_params);
        _chargingdata_post_400_response->invalid_params = NULL;
    }
    if (_chargingdata_post_400_response->supported_features) {
        ogs_free(_chargingdata_post_400_response->supported_features);
        _chargingdata_post_400_response->supported_features = NULL;
    }
    if (_chargingdata_post_400_response->access_token_error) {
        OpenAPI_access_token_err_free(_chargingdata_post_400_response->access_token_error);
        _chargingdata_post_400_response->access_token_error = NULL;
    }
    if (_chargingdata_post_400_response->access_token_request) {
        OpenAPI_access_token_req_free(_chargingdata_post_400_response->access_token_request);
        _chargingdata_post_400_response->access_token_request = NULL;
    }
    if (_chargingdata_post_400_response->nrf_id) {
        ogs_free(_chargingdata_post_400_response->nrf_id);
        _chargingdata_post_400_response->nrf_id = NULL;
    }
    if (_chargingdata_post_400_response->invocation_result) {
        OpenAPI_invocation_result_free(_chargingdata_post_400_response->invocation_result);
        _chargingdata_post_400_response->invocation_result = NULL;
    }
    ogs_free(_chargingdata_post_400_response);
}

cJSON *OpenAPI__chargingdata_post_400_response_convertToJSON(OpenAPI__chargingdata_post_400_response_t *_chargingdata_post_400_response)
{
    cJSON *item = NULL;
    OpenAPI_lnode_t *node = NULL;

    if (_chargingdata_post_400_response == NULL) {
        ogs_error("OpenAPI__chargingdata_post_400_response_convertToJSON() failed [_chargingdata_post_400_response]");
        return NULL;
    }

    item = cJSON_CreateObject();
    if (_chargingdata_post_400_response->type) {
    if (cJSON_AddStringToObject(item, "type", _chargingdata_post_400_response->type) == NULL) {
        ogs_error("OpenAPI__chargingdata_post_400_response_convertToJSON() failed [type]");
        goto end;
    }
    }

    if (_chargingdata_post_400_response->title) {
    if (cJSON_AddStringToObject(item, "title", _chargingdata_post_400_response->title) == NULL) {
        ogs_error("OpenAPI__chargingdata_post_400_response_convertToJSON() failed [title]");
        goto end;
    }
    }

    if (_chargingdata_post_400_response->is_status) {
    if (cJSON_AddNumberToObject(item, "status", _chargingdata_post_400_response->status) == NULL) {
        ogs_error("OpenAPI__chargingdata_post_400_response_convertToJSON() failed [status]");
        goto end;
    }
    }

    if (_chargingdata_post_400_response->detail) {
    if (cJSON_AddStringToObject(item, "detail", _chargingdata_post_400_response->detail) == NULL) {
        ogs_error("OpenAPI__chargingdata_post_400_response_convertToJSON() failed [detail]");
        goto end;
    }
    }

    if (_chargingdata_post_400_response->instance) {
    if (cJSON_AddStringToObject(item, "instance", _chargingdata_post_400_response->instance) == NULL) {
        ogs_error("OpenAPI__chargingdata_post_400_response_convertToJSON() failed [instance]");
        goto end;
    }
    }

    if (_chargingdata_post_400_response->cause) {
    if (cJSON_AddStringToObject(item, "cause", _chargingdata_post_400_response->cause) == NULL) {
        ogs_error("OpenAPI__chargingdata_post_400_response_convertToJSON() failed [cause]");
        goto end;
    }
    }

    if (_chargingdata_post_400_response->invalid_params) {
    cJSON *invalid_paramsList = cJSON_AddArrayToObject(item, "invalidParams");
    if (invalid_paramsList == NULL) {
        ogs_error("OpenAPI__chargingdata_post_400_response_convertToJSON() failed [invalid_params]");
        goto end;
    }
    OpenAPI_list_for_each(_chargingdata_post_400_response->invalid_params, node) {
        cJSON *itemLocal = OpenAPI_invalid_param_convertToJSON(node->data);
        if (itemLocal == NULL) {
            ogs_error("OpenAPI__chargingdata_post_400_response_convertToJSON() failed [invalid_params]");
            goto end;
        }
        cJSON_AddItemToArray(invalid_paramsList, itemLocal);
    }
    }

    if (_chargingdata_post_400_response->supported_features) {
    if (cJSON_AddStringToObject(item, "supportedFeatures", _chargingdata_post_400_response->supported_features) == NULL) {
        ogs_error("OpenAPI__chargingdata_post_400_response_convertToJSON() failed [supported_features]");
        goto end;
    }
    }

    if (_chargingdata_post_400_response->access_token_error) {
    cJSON *access_token_error_local_JSON = OpenAPI_access_token_err_convertToJSON(_chargingdata_post_400_response->access_token_error);
    if (access_token_error_local_JSON == NULL) {
        ogs_error("OpenAPI__chargingdata_post_400_response_convertToJSON() failed [access_token_error]");
        goto end;
    }
    cJSON_AddItemToObject(item, "accessTokenError", access_token_error_local_JSON);
    if (item->child == NULL) {
        ogs_error("OpenAPI__chargingdata_post_400_response_convertToJSON() failed [access_token_error]");
        goto end;
    }
    }

    if (_chargingdata_post_400_response->access_token_request) {
    cJSON *access_token_request_local_JSON = OpenAPI_access_token_req_convertToJSON(_chargingdata_post_400_response->access_token_request);
    if (access_token_request_local_JSON == NULL) {
        ogs_error("OpenAPI__chargingdata_post_400_response_convertToJSON() failed [access_token_request]");
        goto end;
    }
    cJSON_AddItemToObject(item, "accessTokenRequest", access_token_request_local_JSON);
    if (item->child == NULL) {
        ogs_error("OpenAPI__chargingdata_post_400_response_convertToJSON() failed [access_token_request]");
        goto end;
    }
    }

    if (_chargingdata_post_400_response->nrf_id) {
    if (cJSON_AddStringToObject(item, "nrfId", _chargingdata_post_400_response->nrf_id) == NULL) {
        ogs_error("OpenAPI__chargingdata_post_400_response_convertToJSON() failed [nrf_id]");
        goto end;
    }
    }

    if (_chargingdata_post_400_response->invocation_result) {
    cJSON *invocation_result_local_JSON = OpenAPI_invocation_result_convertToJSON(_chargingdata_post_400_response->invocation_result);
    if (invocation_result_local_JSON == NULL) {
        ogs_error("OpenAPI__chargingdata_post_400_response_convertToJSON() failed [invocation_result]");
        goto end;
    }
    cJSON_AddItemToObject(item, "invocationResult", invocation_result_local_JSON);
    if (item->child == NULL) {
        ogs_error("OpenAPI__chargingdata_post_400_response_convertToJSON() failed [invocation_result]");
        goto end;
    }
    }

end:
    return item;
}

OpenAPI__chargingdata_post_400_response_t *OpenAPI__chargingdata_post_400_response_parseFromJSON(cJSON *_chargingdata_post_400_responseJSON)
{
    OpenAPI__chargingdata_post_400_response_t *_chargingdata_post_400_response_local_var = NULL;
    OpenAPI_lnode_t *node = NULL;
    cJSON *type = NULL;
    cJSON *title = NULL;
    cJSON *status = NULL;
    cJSON *detail = NULL;
    cJSON *instance = NULL;
    cJSON *cause = NULL;
    cJSON *invalid_params = NULL;
    OpenAPI_list_t *invalid_paramsList = NULL;
    cJSON *supported_features = NULL;
    cJSON *access_token_error = NULL;
    OpenAPI_access_token_err_t *access_token_error_local_nonprim = NULL;
    cJSON *access_token_request = NULL;
    OpenAPI_access_token_req_t *access_token_request_local_nonprim = NULL;
    cJSON *nrf_id = NULL;
    cJSON *invocation_result = NULL;
    OpenAPI_invocation_result_t *invocation_result_local_nonprim = NULL;
    type = cJSON_GetObjectItemCaseSensitive(_chargingdata_post_400_responseJSON, "type");
    if (type) {
    if (!cJSON_IsString(type) && !cJSON_IsNull(type)) {
        ogs_error("OpenAPI__chargingdata_post_400_response_parseFromJSON() failed [type]");
        goto end;
    }
    }

    title = cJSON_GetObjectItemCaseSensitive(_chargingdata_post_400_responseJSON, "title");
    if (title) {
    if (!cJSON_IsString(title) && !cJSON_IsNull(title)) {
        ogs_error("OpenAPI__chargingdata_post_400_response_parseFromJSON() failed [title]");
        goto end;
    }
    }

    status = cJSON_GetObjectItemCaseSensitive(_chargingdata_post_400_responseJSON, "status");
    if (status) {
    if (!cJSON_IsNumber(status)) {
        ogs_error("OpenAPI__chargingdata_post_400_response_parseFromJSON() failed [status]");
        goto end;
    }
    }

    detail = cJSON_GetObjectItemCaseSensitive(_chargingdata_post_400_responseJSON, "detail");
    if (detail) {
    if (!cJSON_IsString(detail) && !cJSON_IsNull(detail)) {
        ogs_error("OpenAPI__chargingdata_post_400_response_parseFromJSON() failed [detail]");
        goto end;
    }
    }

    instance = cJSON_GetObjectItemCaseSensitive(_chargingdata_post_400_responseJSON, "instance");
    if (instance) {
    if (!cJSON_IsString(instance) && !cJSON_IsNull(instance)) {
        ogs_error("OpenAPI__chargingdata_post_400_response_parseFromJSON() failed [instance]");
        goto end;
    }
    }

    cause = cJSON_GetObjectItemCaseSensitive(_chargingdata_post_400_responseJSON, "cause");
    if (cause) {
    if (!cJSON_IsString(cause) && !cJSON_IsNull(cause)) {
        ogs_error("OpenAPI__chargingdata_post_400_response_parseFromJSON() failed [cause]");
        goto end;
    }
    }

    invalid_params = cJSON_GetObjectItemCaseSensitive(_chargingdata_post_400_responseJSON, "invalidParams");
    if (invalid_params) {
        cJSON *invalid_params_local = NULL;
        if (!cJSON_IsArray(invalid_params)) {
            ogs_error("OpenAPI__chargingdata_post_400_response_parseFromJSON() failed [invalid_params]");
            goto end;
        }

        invalid_paramsList = OpenAPI_list_create();

        cJSON_ArrayForEach(invalid_params_local, invalid_params) {
            if (!cJSON_IsObject(invalid_params_local)) {
                ogs_error("OpenAPI__chargingdata_post_400_response_parseFromJSON() failed [invalid_params]");
                goto end;
            }
            OpenAPI_invalid_param_t *invalid_paramsItem = OpenAPI_invalid_param_parseFromJSON(invalid_params_local);
            if (!invalid_paramsItem) {
                ogs_error("No invalid_paramsItem");
                goto end;
            }
            OpenAPI_list_add(invalid_paramsList, invalid_paramsItem);
        }
    }

    supported_features = cJSON_GetObjectItemCaseSensitive(_chargingdata_post_400_responseJSON, "supportedFeatures");
    if (supported_features) {
    if (!cJSON_IsString(supported_features) && !cJSON_IsNull(supported_features)) {
        ogs_error("OpenAPI__chargingdata_post_400_response_parseFromJSON() failed [supported_features]");
        goto end;
    }
    }

    access_token_error = cJSON_GetObjectItemCaseSensitive(_chargingdata_post_400_responseJSON, "accessTokenError");
    if (access_token_error) {
    access_token_error_local_nonprim = OpenAPI_access_token_err_parseFromJSON(access_token_error);
    if (!access_token_error_local_nonprim) {
        ogs_error("OpenAPI_access_token_err_parseFromJSON failed [access_token_error]");
        goto end;
    }
    }

    access_token_request = cJSON_GetObjectItemCaseSensitive(_chargingdata_post_400_responseJSON, "accessTokenRequest");
    if (access_token_request) {
    access_token_request_local_nonprim = OpenAPI_access_token_req_parseFromJSON(access_token_request);
    if (!access_token_request_local_nonprim) {
        ogs_error("OpenAPI_access_token_req_parseFromJSON failed [access_token_request]");
        goto end;
    }
    }

    nrf_id = cJSON_GetObjectItemCaseSensitive(_chargingdata_post_400_responseJSON, "nrfId");
    if (nrf_id) {
    if (!cJSON_IsString(nrf_id) && !cJSON_IsNull(nrf_id)) {
        ogs_error("OpenAPI__chargingdata_post_400_response_parseFromJSON() failed [nrf_id]");
        goto end;
    }
    }

    invocation_result = cJSON_GetObjectItemCaseSensitive(_chargingdata_post_400_responseJSON, "invocationResult");
    if (invocation_result) {
    invocation_result_local_nonprim = OpenAPI_invocation_result_parseFromJSON(invocation_result);
    if (!invocation_result_local_nonprim) {
        ogs_error("OpenAPI_invocation_result_parseFromJSON failed [invocation_result]");
        goto end;
    }
    }

    _chargingdata_post_400_response_local_var = OpenAPI__chargingdata_post_400_response_create (
        type && !cJSON_IsNull(type) ? ogs_strdup(type->valuestring) : NULL,
        title && !cJSON_IsNull(title) ? ogs_strdup(title->valuestring) : NULL,
        status ? true : false,
        status ? status->valuedouble : 0,
        detail && !cJSON_IsNull(detail) ? ogs_strdup(detail->valuestring) : NULL,
        instance && !cJSON_IsNull(instance) ? ogs_strdup(instance->valuestring) : NULL,
        cause && !cJSON_IsNull(cause) ? ogs_strdup(cause->valuestring) : NULL,
        invalid_params ? invalid_paramsList : NULL,
        supported_features && !cJSON_IsNull(supported_features) ? ogs_strdup(supported_features->valuestring) : NULL,
        access_token_error ? access_token_error_local_nonprim : NULL,
        access_token_request ? access_token_request_local_nonprim : NULL,
        nrf_id && !cJSON_IsNull(nrf_id) ? ogs_strdup(nrf_id->valuestring) : NULL,
        invocation_result ? invocation_result_local_nonprim : NULL
    );

    return _chargingdata_post_400_response_local_var;
end:
    if (invalid_paramsList) {
        OpenAPI_list_for_each(invalid_paramsList, node) {
            OpenAPI_invalid_param_free(node->data);
        }
        OpenAPI_list_free(invalid_paramsList);
        invalid_paramsList = NULL;
    }
    if (access_token_error_local_nonprim) {
        OpenAPI_access_token_err_free(access_token_error_local_nonprim);
        access_token_error_local_nonprim = NULL;
    }
    if (access_token_request_local_nonprim) {
        OpenAPI_access_token_req_free(access_token_request_local_nonprim);
        access_token_request_local_nonprim = NULL;
    }
    if (invocation_result_local_nonprim) {
        OpenAPI_invocation_result_free(invocation_result_local_nonprim);
        invocation_result_local_nonprim = NULL;
    }
    return NULL;
}

OpenAPI__chargingdata_post_400_response_t *OpenAPI__chargingdata_post_400_response_copy(OpenAPI__chargingdata_post_400_response_t *dst, OpenAPI__chargingdata_post_400_response_t *src)
{
    cJSON *item = NULL;
    char *content = NULL;

    ogs_assert(src);
    item = OpenAPI__chargingdata_post_400_response_convertToJSON(src);
    if (!item) {
        ogs_error("OpenAPI__chargingdata_post_400_response_convertToJSON() failed");
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

    OpenAPI__chargingdata_post_400_response_free(dst);
    dst = OpenAPI__chargingdata_post_400_response_parseFromJSON(item);
    cJSON_Delete(item);

    return dst;
}

