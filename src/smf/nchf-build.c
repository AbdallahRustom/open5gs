#include "nchf-build.h"
#include "model/nf_identification.h"
#include "sbi-path.h"

ogs_sbi_request_t *smf_nchf_build_get(smf_sess_t *sess, void *data){

    ogs_info("*****nchf-build.c: smf_nchf_build_get()*****");

    ogs_sbi_message_t message;
    ogs_sbi_header_t header;
    ogs_sbi_request_t *request = NULL;
    ogs_sbi_server_t *server = NULL;
    OpenAPI_nf_identification_t nf_identification;
    OpenAPI_pdu_session_charging_information_t pdu_session_charging_information;
    OpenAPI_user_information_t user_information;
    OpenAPI_pdu_session_information_t pdu_session_information;
    OpenAPI_network_slicing_info_t network_slicing_info;
    OpenAPI_snssai_t snssai;
    OpenAPI_serving_network_function_id_t serving_network_function_id;

    ogs_uuid_t uuid;
    char id[OGS_UUID_FORMATTED_LENGTH + 1];

    server = ogs_sbi_server_first();
    if(!server){
        ogs_error("No Server");
    }

    OpenAPI_charging_data_request_t ChargingDataRequest;

    smf_ue_t *smf_ue = NULL;

    memset(&user_information, 0, sizeof(user_information));
    memset(&nf_identification, 0, sizeof(nf_identification));
    memset(&message, 0, sizeof(message));
    memset(&header, 0, sizeof(header));
    memset(&ChargingDataRequest, 0, sizeof(ChargingDataRequest));
    memset(&pdu_session_charging_information, 0, sizeof(pdu_session_charging_information));
    memset(&pdu_session_information, 0, sizeof(pdu_session_information));
    memset(&network_slicing_info, 0, sizeof(network_slicing_info));
    memset(&snssai, 0, sizeof(snssai));
    memset(&serving_network_function_id, 0, sizeof(serving_network_function_id));

    ogs_assert(sess);
    ogs_assert(sess->sm_context_ref);
    ogs_assert(sess->session.name);
    smf_ue = smf_ue_find_by_id(sess->smf_ue_id);
    ogs_assert(smf_ue);

    message.h.method = (char *)OGS_SBI_HTTP_METHOD_POST;
    message.h.service.name = (char *)OGS_SBI_SERVICE_NAME_NCHF_CONVERGEDCHARGING;
    message.h.api.version = (char *)OGS_SBI_API_V1;
    message.h.resource.component[0] = (char *)"chargingdata";
    message.http.content_type = (char *)OGS_SBI_CONTENT_JSON_TYPE;

    ogs_uuid_get(&uuid);
    ogs_uuid_format(id, &uuid);
    const char* notify_urn = "notify_urn:uuid:";
    char *notify_uri = ogs_msprintf("%s%s", notify_urn, id);

    //TODO: remove OGS_SBI_API_V1
    header.service.name = (char *)OGS_SBI_SERVICE_NAME_NSMF_CALLBACK;
    header.api.version = (char *)OGS_SBI_API_V1;    
    header.resource.component[0] = (char *)notify_uri;

    ChargingDataRequest.subscriber_identifier = smf_ue->supi;

    ChargingDataRequest.is_charging_id = sess->charging.id;

    nf_identification.n_f_name = OpenAPI_node_functionality_any_of_ToString(OpenAPI_node_functionality_any_of_SMF);
    nf_identification.n_node_functionality = OpenAPI_node_functionality_any_of_ToString(OpenAPI_node_functionality_any_of_SMF);
    nf_identification.n_fipv4_address = ogs_ipv4_to_string(sess->ipv4->addr[0]);

    ChargingDataRequest.nf_consumer_identification = &nf_identification;
    
    ChargingDataRequest.invocation_time_stamp = ogs_sbi_gmtime_string(sess->ue_location_timestamp);
    ChargingDataRequest.invocation_sequence_number = 0;
    ChargingDataRequest.notify_uri = ogs_sbi_server_uri(server, &header);
    
    pdu_session_charging_information.is_charging_id = sess->charging.id;
    
    user_information.served_gpsi = (char *)"msisdn-";
    pdu_session_charging_information.user_information = &user_information;

    pdu_session_charging_information.is_charging_id = sess->charging.id;
    pdu_session_information.pdu_type = OpenAPI_pdu_session_type_IPV4;

    pdu_session_information.dnn_id = ogs_strdup(sess->session.name);
    ogs_assert(pdu_session_information.dnn_id);

    snssai.sst = sess->s_nssai.sst;
    snssai.sd = ogs_s_nssai_sd_to_string(sess->s_nssai.sd);
    if(snssai.sd == NULL) {
        snssai.sd = (char *)"010203";
    }
    network_slicing_info.s_nssai = &snssai;
    pdu_session_information.network_slicing_info = &network_slicing_info;
    
    serving_network_function_id.serving_network_function_information=&nf_identification;
    pdu_session_information.serving_network_function_id = &serving_network_function_id;

    pdu_session_charging_information.pdu_session_information = &pdu_session_information;
    ChargingDataRequest.p_du_session_charging_information = &pdu_session_charging_information;
    message.ChargingDataRequest = &ChargingDataRequest;
    
    request = ogs_sbi_build_request(&message);
    ogs_expect(request);

    return request;
}

ogs_sbi_request_t *smf_nchf_build_report(smf_sess_t *sess, void *data){

    ogs_info("@@@@@@@@@@@@ nchf-build.c: smf_nchf_build_report() @@@@@@@@@@@@");

    ogs_sbi_message_t message;
    ogs_sbi_header_t header;
    ogs_sbi_request_t *request = NULL;
    ogs_sbi_server_t *server = NULL;
    OpenAPI_nf_identification_t nf_identification;
    OpenAPI_pdu_session_charging_information_t pdu_session_charging_information;
    OpenAPI_user_information_t user_information;
    OpenAPI_pdu_session_information_t pdu_session_information;
    OpenAPI_network_slicing_info_t network_slicing_info;
    OpenAPI_snssai_t snssai;
    OpenAPI_serving_network_function_id_t serving_network_function_id;


    ogs_uuid_t uuid;
    char id[OGS_UUID_FORMATTED_LENGTH + 1];

    server = ogs_sbi_server_first();
    if(!server){
        ogs_error("No Server");
    }

    OpenAPI_charging_data_request_t ChargingDataRequest;

    smf_ue_t *smf_ue = NULL;

    memset(&user_information, 0, sizeof(user_information));
    memset(&nf_identification, 0, sizeof(nf_identification));
    memset(&message, 0, sizeof(message));
    memset(&header, 0, sizeof(header));
    memset(&ChargingDataRequest, 0, sizeof(ChargingDataRequest));
    memset(&pdu_session_charging_information, 0, sizeof(pdu_session_charging_information));
    memset(&pdu_session_information, 0, sizeof(pdu_session_information));
    memset(&network_slicing_info, 0, sizeof(network_slicing_info));
    memset(&snssai, 0, sizeof(snssai));
    memset(&serving_network_function_id, 0, sizeof(serving_network_function_id));

    ogs_assert(sess);
    ogs_assert(sess->sm_context_ref);
    ogs_assert(sess->session.name);
    smf_ue = smf_ue_find_by_id(sess->smf_ue_id);
    ogs_assert(smf_ue);

    const char* supi = smf_ue->supi;
    char *supi_smf = ogs_msprintf("%s%s", supi, "SMF0");

    message.h.method = (char *)OGS_SBI_HTTP_METHOD_POST;
    message.h.service.name = (char *)OGS_SBI_SERVICE_NAME_NCHF_CONVERGEDCHARGING;
    message.h.api.version = (char *)OGS_SBI_API_V1;
    message.h.resource.component[0] = (char *)"chargingdata";
    message.h.resource.component[1] = (char *)supi_smf;
    message.h.resource.component[2] = (char *)OGS_SBI_RESOURCE_NAME_UPDATE;
    message.http.content_type = (char *)OGS_SBI_CONTENT_JSON_TYPE;

    // TODO: Check for uuid
    ogs_uuid_get(&uuid);
    ogs_uuid_format(id, &uuid);
    const char* notify_urn = "notify_urn:uuid:";
    char *notify_uri = ogs_msprintf("%s%s", notify_urn, id);

    //TODO: remove OGS_SBI_API_V1
    header.service.name = (char *)OGS_SBI_SERVICE_NAME_NSMF_CALLBACK;
    header.api.version = (char *)OGS_SBI_API_V1;    
    header.resource.component[0] = (char *)notify_uri;

    ChargingDataRequest.subscriber_identifier = smf_ue->supi;

    ChargingDataRequest.is_charging_id = sess->charging.id;

    nf_identification.n_f_name = OpenAPI_node_functionality_any_of_ToString(OpenAPI_node_functionality_any_of_SMF);
    nf_identification.n_node_functionality = OpenAPI_node_functionality_any_of_ToString(OpenAPI_node_functionality_any_of_SMF);
    nf_identification.n_fipv4_address = ogs_ipv4_to_string(sess->ipv4->addr[0]);

    ChargingDataRequest.nf_consumer_identification = &nf_identification;
    
    ChargingDataRequest.invocation_time_stamp = ogs_sbi_gmtime_string(sess->ue_location_timestamp);
    ChargingDataRequest.invocation_sequence_number = 0;
    ChargingDataRequest.notify_uri = ogs_sbi_server_uri(server, &header);
    
    pdu_session_charging_information.is_charging_id = sess->charging.id;
    
    user_information.served_gpsi = (char *)"msisdn-";
    pdu_session_charging_information.user_information = &user_information;

    pdu_session_charging_information.is_charging_id = sess->charging.id;
    pdu_session_information.pdu_type = OpenAPI_pdu_session_type_IPV4;

    pdu_session_information.dnn_id = ogs_strdup(sess->session.name);
    ogs_assert(pdu_session_information.dnn_id);

    snssai.sst = sess->s_nssai.sst;
    snssai.sd = ogs_s_nssai_sd_to_string(sess->s_nssai.sd);
    if(snssai.sd == NULL) {
        snssai.sd = (char *)"010203";
    }
    network_slicing_info.s_nssai = &snssai;
    pdu_session_information.network_slicing_info = &network_slicing_info;
    
    serving_network_function_id.serving_network_function_information=&nf_identification;
    pdu_session_information.serving_network_function_id = &serving_network_function_id;

    pdu_session_charging_information.pdu_session_information = &pdu_session_information;
    ChargingDataRequest.p_du_session_charging_information = &pdu_session_charging_information;

    // Data returned from report request (Volume -- Multiple Unit Usage)

    OpenAPI_multiple_unit_usage_t *multiple_unit_usage = NULL;
    memset(&multiple_unit_usage, 0, sizeof(multiple_unit_usage));

    OpenAPI_requested_unit_t* requested_unit = OpenAPI_requested_unit_create(0, 0, 1, 1000, 1, 1000, 1, 1000, 0, 0);

    uint64_t uplink = sess->gy.ul_octets;
    uint64_t downlink = sess->gy.dl_octets;
    uint64_t totalvolume = uplink+downlink;
    char* triggertimestamp  = ogs_sbi_gmtime_string(sess->ue_location_timestamp);
    char* quotaindicator = OpenAPI_quota_management_indicator_any_of_ToString(OpenAPI_quota_management_indicator_any_of_ONLINE_CHARGING);
    /****************************************** */
    char* triggertype  = NULL;
    triggertype = OpenAPI_trigger_type_any_of_ToString(OpenAPI_trigger_type_any_of_QUOTA_THRESHOLD);
        if( sess->pfcp_report_request->usage_report[0].usage_report_trigger.u24 & (1 << 20 ) ){
            triggertype =  OpenAPI_trigger_type_any_of_ToString(OpenAPI_trigger_type_any_of_START_OF_SERVICE_DATA_FLOW);
        }
     
    char* triggercategory  = OpenAPI_trigger_category_any_of_ToString(OpenAPI_trigger_category_any_of_IMMEDIATE_REPORT);


    OpenAPI_trigger_t *trigger = OpenAPI_trigger_create(triggertype,triggercategory,0,0,0,0,0,0,0,0,0,0,NULL);
    
    OpenAPI_list_t *trigger_list = OpenAPI_list_create();
    OpenAPI_list_add(trigger_list, trigger);
   
   
   /****************************************** */
   
    OpenAPI_used_unit_container_t *used_unit_container = NULL;
    if( sess->pfcp_report_request->usage_report[0].usage_report_trigger.u24 & (1 << 20 )   ){
    used_unit_container = OpenAPI_used_unit_container_create(0, 0, quotaindicator , trigger_list,triggertimestamp, 0, 0,0,0,0,0,0,0, 0, 0, NULL, 0, NULL, NULL, NULL);
    } else {
    used_unit_container = OpenAPI_used_unit_container_create(0, 0, quotaindicator , trigger_list,triggertimestamp, 0, 0,1,totalvolume,1, uplink,1, downlink, 0, 0, NULL, 0, NULL, NULL, NULL);

    }


    OpenAPI_list_t *used_unit_container_list = OpenAPI_list_create();
    OpenAPI_list_add(used_unit_container_list, used_unit_container);

    
    multiple_unit_usage = OpenAPI_multiple_unit_usage_create(1, requested_unit, used_unit_container_list ,(char *) "cae10c71-ee59-4498-ad50-12c013c3d375", NULL);


    OpenAPI_list_t *multiple_unit_usage_list = OpenAPI_list_create();
    OpenAPI_list_add(multiple_unit_usage_list, multiple_unit_usage);

    ChargingDataRequest.multiple_unit_usage = multiple_unit_usage_list;
    ChargingDataRequest.triggers = trigger_list;
    // ------------ End of (Volume -- Multiple Unit Usage) --------------


    

    message.ChargingDataRequest = &ChargingDataRequest;
    
    request = ogs_sbi_build_request(&message);
    ogs_expect(request);

    return request;
}

// bool smf_nchf_build_and_send(ogs_sbi_service_type_e service_type,
//         ogs_sbi_request_t *(*build)(smf_sess_t *sess, void *data),
//         smf_sess_t *sess, int state, void *data)
// {
//     ogs_info("@@@@@@@@@@@@ nchf-build.c: smf_nchf_build_and_send() @@@@@@@@@@@@");

//     ogs_sbi_xact_t *xact = NULL;
//     ogs_sbi_nf_instance_t *nf_instance = NULL;

//     nf_instance = ogs_sbi_nf_instance_find_by_service_type(service_type, OpenAPI_nf_type_CHF);

//     xact = ogs_sbi_xact_add(
//             sess->id, &sess->sbi, service_type, NULL,
//             (ogs_sbi_build_f)build, sess, data);
//     if (!xact) {
//         ogs_error("smf_sbi_discover_and_send() failed");
//         return OGS_ERROR;
//     }

//     xact->state = state;

//     return smf_sbi_send_request(nf_instance, xact);
// }
