osmo-ePDG
=========

This project is about the implementation of an ePDG (evolved Packet Data Gateway)
within the 3GPP EPC (Evolved Packet Core) architecture. It is part of the
[Osmocom](https://osmocom.org/) Open Source Mobile Communications project.

The ePDG is what your smartphone talks to when performing so-called VoWiFi calls.

This repostory contains the code implementing the signaling/control plane of
the ePDG functionality, together with an embedded AAA server.

osmo-epdg requires the [Linux kernel GTP-U](https://osmocom.org/projects/linux-kernel-gtp-u/wiki)
as well as a [modified strongwan](https://gitea.osmocom.org/ims-volte-vowifi/strongswan/src/branch/osmo-epdg)

    [UE] <-> [strongswan] <-> [osmo-ePDG] <> [HSS]
                                          <> [PGW]


Homepage
--------

For more information, please see the [osmo-epdg homepage](https://osmocom.org/projects/osmo-epdg/wiki/) and more
specifically the [osmo-epdg implementation plan](https://osmocom.org/projects/osmo-epdg/wiki/EPDG_implementation_plan)


GIT Repository
--------------

You can clone from the official osmo-epdg.git repository using

        git clone https://gitea.osmocom.org/erlang/osmo-epdg

There is a web interface at <https://gitea.osmocom.org/erlang/osmo-epdg>


Documentation
-------------

Once the project reaches a usable milestone, we will be working on a
user manual.  Stay tuned.


Contributing
------------

Our coding standards are described at
<https://osmocom.org/projects/cellular-infrastructure/wiki/Coding_standards>

We us a gerrit based patch submission/review process for managing
contributions.  Please see
<https://osmocom.org/projects/cellular-infrastructure/wiki/Gerrit> for
more details

The current patch queue for osmo-epdg can be seen at
<https://gerrit.osmocom.org/#/q/project:erlang/osmo-epdg+status:open>


Building
--------

Install erlang and rebar3 packages (not "rebar", that's version 2! You may need
to compile it from source in some distros).

    $ rebar3 compile
    $ rebar3 escriptize

Testing
-------

Unit tests can be run this way:

    $ rebar3 eunit

Running
-------

Once osmo\_epdg is built, you can start it this way:

    $ rebar3 shell

In the erlang shell:

    1> osmo_epdg:start().

Configuration
-------------

    $ rebar3 shell --config ./config/sys.config

    1> osmo_epdg:start().

