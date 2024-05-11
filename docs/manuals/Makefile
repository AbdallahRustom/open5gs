# A simplistic Makefile to use without autoconf
#
# Install osmo-gsm-manuals or use `export OSMO_GSM_MANUALS_DIR=/path/to/osmo-gsm-manuals`

OSMO_GSM_MANUALS_DIR ?= /usr/share/osmo-gsm-manuals/
srcdir ?= $(realpath .)

ASCIIDOC = osmoepdg-usermanual.adoc
ASCIIDOC_DEPS = $(srcdir)/chapters/*.adoc $(srcdir)/*.dot $(srcdir)/*.msc
include $(OSMO_GSM_MANUALS_DIR)/build/Makefile.asciidoc.inc

OSMO_REPOSITORY = osmo-epdg
include $(OSMO_GSM_MANUALS_DIR)/build/Makefile.common.inc
