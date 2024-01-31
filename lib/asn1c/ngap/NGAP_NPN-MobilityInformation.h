/*
 * Generated by asn1c-0.9.29 (http://lionet.info/asn1c)
 * From ASN.1 module "NGAP-IEs"
 * 	found in "../support/ngap-r17.3.0/38413-h30.asn"
 * 	`asn1c -pdu=all -fcompound-names -findirect-choice -fno-include-deps -no-gen-BER -no-gen-XER -no-gen-OER -no-gen-UPER`
 */

#ifndef	_NGAP_NPN_MobilityInformation_H_
#define	_NGAP_NPN_MobilityInformation_H_


#include <asn_application.h>

/* Including external dependencies */
#include <constr_CHOICE.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Dependencies */
typedef enum NGAP_NPN_MobilityInformation_PR {
	NGAP_NPN_MobilityInformation_PR_NOTHING,	/* No components present */
	NGAP_NPN_MobilityInformation_PR_sNPN_MobilityInformation,
	NGAP_NPN_MobilityInformation_PR_pNI_NPN_MobilityInformation,
	NGAP_NPN_MobilityInformation_PR_choice_Extensions
} NGAP_NPN_MobilityInformation_PR;

/* Forward declarations */
struct NGAP_SNPN_MobilityInformation;
struct NGAP_PNI_NPN_MobilityInformation;
struct NGAP_ProtocolIE_SingleContainer;

/* NGAP_NPN-MobilityInformation */
typedef struct NGAP_NPN_MobilityInformation {
	NGAP_NPN_MobilityInformation_PR present;
	union NGAP_NPN_MobilityInformation_u {
		struct NGAP_SNPN_MobilityInformation	*sNPN_MobilityInformation;
		struct NGAP_PNI_NPN_MobilityInformation	*pNI_NPN_MobilityInformation;
		struct NGAP_ProtocolIE_SingleContainer	*choice_Extensions;
	} choice;
	
	/* Context for parsing across buffer boundaries */
	asn_struct_ctx_t _asn_ctx;
} NGAP_NPN_MobilityInformation_t;

/* Implementation */
extern asn_TYPE_descriptor_t asn_DEF_NGAP_NPN_MobilityInformation;
extern asn_CHOICE_specifics_t asn_SPC_NGAP_NPN_MobilityInformation_specs_1;
extern asn_TYPE_member_t asn_MBR_NGAP_NPN_MobilityInformation_1[3];
extern asn_per_constraints_t asn_PER_type_NGAP_NPN_MobilityInformation_constr_1;

#ifdef __cplusplus
}
#endif

#endif	/* _NGAP_NPN_MobilityInformation_H_ */
#include <asn_internal.h>
