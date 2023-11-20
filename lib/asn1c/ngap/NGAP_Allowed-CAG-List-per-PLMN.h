/*
 * Generated by asn1c-0.9.29 (http://lionet.info/asn1c)
 * From ASN.1 module "NGAP-IEs"
 * 	found in "../support/ngap-r16.7.0/38413-g70.asn"
 * 	`asn1c -pdu=all -fcompound-names -findirect-choice -fno-include-deps -no-gen-BER -no-gen-XER -no-gen-OER -no-gen-UPER`
 */

#ifndef	_NGAP_Allowed_CAG_List_per_PLMN_H_
#define	_NGAP_Allowed_CAG_List_per_PLMN_H_


#include <asn_application.h>

/* Including external dependencies */
#include "NGAP_CAG-ID.h"
#include <asn_SEQUENCE_OF.h>
#include <constr_SEQUENCE_OF.h>

#ifdef __cplusplus
extern "C" {
#endif

/* NGAP_Allowed-CAG-List-per-PLMN */
typedef struct NGAP_Allowed_CAG_List_per_PLMN {
	A_SEQUENCE_OF(NGAP_CAG_ID_t) list;
	
	/* Context for parsing across buffer boundaries */
	asn_struct_ctx_t _asn_ctx;
} NGAP_Allowed_CAG_List_per_PLMN_t;

/* Implementation */
extern asn_TYPE_descriptor_t asn_DEF_NGAP_Allowed_CAG_List_per_PLMN;
extern asn_SET_OF_specifics_t asn_SPC_NGAP_Allowed_CAG_List_per_PLMN_specs_1;
extern asn_TYPE_member_t asn_MBR_NGAP_Allowed_CAG_List_per_PLMN_1[1];
extern asn_per_constraints_t asn_PER_type_NGAP_Allowed_CAG_List_per_PLMN_constr_1;

#ifdef __cplusplus
}
#endif

#endif	/* _NGAP_Allowed_CAG_List_per_PLMN_H_ */
#include <asn_internal.h>
