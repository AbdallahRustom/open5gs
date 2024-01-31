/*
 * Generated by asn1c-0.9.29 (http://lionet.info/asn1c)
 * From ASN.1 module "NGAP-IEs"
 * 	found in "../support/ngap-r17.3.0/38413-h30.asn"
 * 	`asn1c -pdu=all -fcompound-names -findirect-choice -fno-include-deps -no-gen-BER -no-gen-XER -no-gen-OER -no-gen-UPER`
 */

#ifndef	_NGAP_SourceNodeID_H_
#define	_NGAP_SourceNodeID_H_


#include <asn_application.h>

/* Including external dependencies */
#include <constr_CHOICE.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Dependencies */
typedef enum NGAP_SourceNodeID_PR {
	NGAP_SourceNodeID_PR_NOTHING,	/* No components present */
	NGAP_SourceNodeID_PR_sourceengNB_ID,
	NGAP_SourceNodeID_PR_choice_Extensions
} NGAP_SourceNodeID_PR;

/* Forward declarations */
struct NGAP_GlobalGNB_ID;
struct NGAP_ProtocolIE_SingleContainer;

/* NGAP_SourceNodeID */
typedef struct NGAP_SourceNodeID {
	NGAP_SourceNodeID_PR present;
	union NGAP_SourceNodeID_u {
		struct NGAP_GlobalGNB_ID	*sourceengNB_ID;
		struct NGAP_ProtocolIE_SingleContainer	*choice_Extensions;
	} choice;
	
	/* Context for parsing across buffer boundaries */
	asn_struct_ctx_t _asn_ctx;
} NGAP_SourceNodeID_t;

/* Implementation */
extern asn_TYPE_descriptor_t asn_DEF_NGAP_SourceNodeID;
extern asn_CHOICE_specifics_t asn_SPC_NGAP_SourceNodeID_specs_1;
extern asn_TYPE_member_t asn_MBR_NGAP_SourceNodeID_1[2];
extern asn_per_constraints_t asn_PER_type_NGAP_SourceNodeID_constr_1;

#ifdef __cplusplus
}
#endif

#endif	/* _NGAP_SourceNodeID_H_ */
#include <asn_internal.h>
