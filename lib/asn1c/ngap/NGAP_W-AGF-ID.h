/*
 * Generated by asn1c-0.9.29 (http://lionet.info/asn1c)
 * From ASN.1 module "NGAP-IEs"
 * 	found in "../support/ngap-r17.3.0/38413-h30.asn"
 * 	`asn1c -pdu=all -fcompound-names -findirect-choice -fno-include-deps -no-gen-BER -no-gen-XER -no-gen-OER -no-gen-UPER`
 */

#ifndef	_NGAP_W_AGF_ID_H_
#define	_NGAP_W_AGF_ID_H_


#include <asn_application.h>

/* Including external dependencies */
#include <BIT_STRING.h>
#include <constr_CHOICE.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Dependencies */
typedef enum NGAP_W_AGF_ID_PR {
	NGAP_W_AGF_ID_PR_NOTHING,	/* No components present */
	NGAP_W_AGF_ID_PR_w_AGF_ID,
	NGAP_W_AGF_ID_PR_choice_Extensions
} NGAP_W_AGF_ID_PR;

/* Forward declarations */
struct NGAP_ProtocolIE_SingleContainer;

/* NGAP_W-AGF-ID */
typedef struct NGAP_W_AGF_ID {
	NGAP_W_AGF_ID_PR present;
	union NGAP_W_AGF_ID_u {
		BIT_STRING_t	 w_AGF_ID;
		struct NGAP_ProtocolIE_SingleContainer	*choice_Extensions;
	} choice;
	
	/* Context for parsing across buffer boundaries */
	asn_struct_ctx_t _asn_ctx;
} NGAP_W_AGF_ID_t;

/* Implementation */
extern asn_TYPE_descriptor_t asn_DEF_NGAP_W_AGF_ID;
extern asn_CHOICE_specifics_t asn_SPC_NGAP_W_AGF_ID_specs_1;
extern asn_TYPE_member_t asn_MBR_NGAP_W_AGF_ID_1[2];
extern asn_per_constraints_t asn_PER_type_NGAP_W_AGF_ID_constr_1;

#ifdef __cplusplus
}
#endif

#endif	/* _NGAP_W_AGF_ID_H_ */
#include <asn_internal.h>
