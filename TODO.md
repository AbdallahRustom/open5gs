# TODO

- introduce a gen_fsm to hold all the state
- async calls (e.g. terminate subscription)
- improve and understand the supervisor
 - when the gsup_server dies, it should only restart the gsup_server
 - same for aaa_diameter_swx

- linting for erlang?

## upstream dependencies

### wireshark

- add message class 5 -> IPSEC_EPDG

### libosmocore

- upstream message class

### osmo_ss7

- upstream changes

### osmo_gsup

- upstream changes
