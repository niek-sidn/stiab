# Stiab: DNSSEC Signer street-in-a-box


> The name is an attempt at humorous "Dunglish" (Dutch wrongly translated into English).  
> In Dutch the word for street can be used to describe a series of connected or ordered items, like a straight in poker or in a game of dice.  
> Here we create a straight of interconnected nameservers.

## Goal:
Deploy a chain of nameservers creating a signed TLD DNS zone that can be DNSSEC validated with dig, delv, drill and dnsviz via a recursor.  
Based on Ubuntu, Docker (build/compose), NSD, Knot, Unbound, DNSviz, etc.  
> [!CAUTION]
> You are an utter fool and deserve to be whipped in public if you use this setup in production. Use this software at your own risk.

After you have built all docker images from the included Dockerfiles, you should be able to 'just run' `docker compose up -d` and get a working dnssec signing setup. Provided your host has Docker of course. (E.g. `apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin` Also: see below).  
*TODO*: include image builds in compose file

    docker build -t nsd-stiab:latest -f dockerfiles/Dockerfile.nsd .
    docker build -t knotd-stiab:latest -f dockerfiles/Dockerfile.knotd .
    docker build -t unbound-stiab:latest -f dockerfiles/Dockerfile.unbound .
    docker build -t dnsclient-stiab:latest -f dockerfiles/Dockerfile.dnsclient .

After you have run `docker compose up -d` you should have a working dnssec signing setup.
A dns-client container with dig, drill, delv is also started, to enter it: `docker exec -it stiab-dns-client-1 bash` (Or see below for some more guidance)

Once up and running you can start altering configs, zonefiles and even swap out or add whole components.
That should hopefully satisfy your testing and designing needs.

### W.I.P alert
> [!CAUTION]
> At the moment this should be considered work in progress.

> * especially the zones TTL's and KASP policies may not be atuned.  
> * inconsistencies between components did happen. *TODO*: /var/lib/stiab -> /var/lib/nsd ?  
> * maybe knot should be running as root in stead of user knot? Or NSD as user nsd?   
> * nameserver configs are still unoptimized and bare bones  
> * we have no TSIGs.  
> * NSD can do validation of the zone file, we should do this.  

## Fake DNS root
A fake dns rootserver is included. This server is a "self contained" dnssec signer, that serves the root zone containing all existing TLDs, and any you invent yourself.
For DNSSEC validation to work this root zone is DNSSEC *resigned*. And the recursor is primed with the fake dns rootserver and trust-anchor instead of the real root zone and trust-anchor.

## Config files
A complete set of working config files is included in this repository. For now these files are handcrafted.  
The actions for handcrafting are included below, so you could start from scratch if you like that kind of thing.  
*TODO*: more automation in creating the config files.

## Zonefile
You can/should supply an unsigned tld.zone file of your own making. But a small working tld.zone is supplied.  
To run a realistic setup, this tld.zone should be supplied often and with a realistic number of changes.

## Components
|  name          |   function                                                                                                                                                                 |
|----------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|nsd-zoneloader  |loads unsigned zone of your TLD, supplies XFRs and notifies to the next in line nameserver: knot-signer.                                                                    |
|knot-signer     |DNSSEC signer for TLD, supplies IXFRs to the next in line nameserver: nsd-validator                                                                                         |
|nsd-validator   |does DNSSEC validation and supplies IXFRs to the next in line nameserver: nsd-dister                                                                                        |
|nsd-dister      |Hidden primary that could theoretically supply IXFRs to your (anycasted) public nameserver setup. However, in this setup it functions as the source of authority for our own TLD. As such it is included as an NS for .tld in the (fake) root.zone                                                                         |
|unbound-recursor|fake dns rooted recursor that enables validation with dig, delv, drill, dnsviz. We need that CD bit!!! root-hints: knot-fakeroot only, trust-anchor is our own .tld ksk's DS|
|knot-fakeroot   |fake dns rootserver, serves a dnssec-stripped, then dnssec resigned (with own keys) root.zone. This root.zone contains your TLD's (A, NS, DS) records.|                                                                                                                                                                       
|dns-client      |here we do our digging, drilling, delving.|                                                                                                                                                                            

## Serials
**NOTE**: files/nsd-zoneloader/zones/tld.zone holds the parent serial (pre-signing serial), update this serial if you change tld.zone. After updating the zone file: `docker exec stiab-nsd-zoneloader-1 nsd-control reload tld`  
**NOTE**: knot-signer will sign, and thus increase the serial, but this is a separate serial from the parent serial. The main reason for knot-signer to keep this separate serial is that RRSIGs expire and need regeneration, wether you change the parent zone or not.  
**NOTE**: repeated docker compose up/down's will repeatedly increment the post signing serial.  
*TODO*: why? It can only be /var/lib/knot/keys/*.mdb, but removing these results in new keys at every docker compose up (and thus a new DS etc.)


# Preparations
## host
If running on real hardware or a dedicated host is impractical, you can use your favorite local virtualization tooling. Mine is Incus.

    sudo -i
    incus launch images:ubuntu/noble --vm stiab
    incus shell stiab
    apt-get update && apt-get upgrade -y

## Install Git
Should your host not have git already:   
`apt-get update && apt-get install git   # or possibly git-core`

## Install docker-ce
(Source: adapted from [https://docs.docker.com/engine/install/ubuntu/](https://docs.docker.com/engine/install/ubuntu/))  

Add Docker's official GPG key:

    apt-get install -y ca-certificates curl
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc

Add the repository to Apt sources:

    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    apt-get update
    apt-get upgrade -y
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin


## Start docker service
`systemctl start docker`   
OR (for persistent docker service)   
`systemctl enable --now docker`

# Deploy
**REMINDER** Did you build the docker images?

    git clone https://github.com/niek-sidn/stiab.git
    cd stiab
    docker compose up -d
    docker compose logs

## Prove it works

    docker exec -it stiab-dns-client-1 bash
    dig +multi +dnssec soa . @172.20.0.15
    dig +multi +dnssec soa tld. @172.20.0.15
    dig +multi +dnssec soa sidn.nl. @172.20.0.15
    dig +multi +dnssec soa doesntexist.tld. @172.20.0.15
    dig +multi +dnssec soa brokendnssec.net. @172.20.0.15
    dig +multi +dnssec soa brokendnssec.net. @172.20.0.15 +cdflag
    drill -S tld. @172.20.0.15 soa
    drill -k /var/lib/dns/conf/root.key -r /var/lib/dns/conf/fake-root.hints -T tld. @172.20.0.15 soa
    drill -k /var/lib/dns/conf/root.key -r /var/lib/dns/conf/fake-root.hints -T sidn.nl. @172.20.0.15 soa
    drill -k /var/lib/dns/conf/root.key -r /var/lib/dns/conf/fake-root.hints -T doesntexist.tld. @172.20.0.15 soa
    drill -k /var/lib/dns/conf/root.key -r /var/lib/dns/conf/fake-root.hints -T brokendnssec.net. @172.20.0.15 soa
    delv +vtrace -a /var/lib/dns/conf/root.key-delv @172.20.0.15 sidn.nl soa
    delv +vtrace -a /var/lib/dns/conf/root.key-delv @172.20.0.15 tld. soa
    delv +vtrace -a /var/lib/dns/conf/root.key-delv @172.20.0.15 doesntexist.tld. soa
    delv +vtrace -a /var/lib/dns/conf/root.key-delv @172.20.0.15 brokendnssec.net. soa +cdflag
    
    (docker compose down)

# Steps to create configs/zones/keys should you want to roll your own
NOTE: Only needed if you do not want to just use the provided "example" configs.

roll your own:
mkdir stiab && de stiab
mkdir dockerfiles entrypoints files

mkdir files/nsd-zoneloader
mkdir files/nsd-zoneloader/zones files/nsd-zoneloader/keys
vim files/nsd-zoneloader/nsd.conf   # Note: zones and key/cert files under /var/lib/stiab/
vim files/nsd-zoneloader/zones/tld.zone
vim dockerfiles/Dockerfile.nsd
docker build -t nsd-stiab:latest -f dockerfiles/Dockerfile.nsd .
docker run --rm -it --entrypoint bash -v ./files/nsd-zoneloader/nsd.conf:/etc/nsd/nsd.conf:ro -v ./files/nsd-zoneloader/keys:/var/lib/stiab/keys:rw nsd-stiab:latest
  nsd-control-setup -d /var/lib/stiab/keys/
  exit

mkdir files/knot-signer
mkdir files/knot-signer/zones files/knot-signer/journal
vim files/knot-signer/knot.conf
(files/knot-signer/zones/tld.zone is created automatically after notify from nsd-zoneloader)
(if not hostname == knot-fakeroot: entrypoint_knotd.sh removes all files/knot-signer/zones files/knot-signer/journal content)
vim dockerfiles/Dockerfile.knotd
docker build -t knotd-stiab:latest -f dockerfiles/Dockerfile.knotd .
docker run --rm -it --entrypoint bash -v ./files/knot-signer/knot.conf:/etc/knot/knot.conf:ro -v ./files/knot-signer/keys:/var/lib/knot/keys:rw -v ./files/knot-signer/zones:/var/lib/knot/zones:rw -v ./files/knot-signer/journal:/var/lib/knot/journal:rw knotd-stiab:latest
  chown --recursive knot:knot /var/lib/knot
  keymgr tld. generate algorithm=13 ksk=yes zsk=no
  keymgr tld. generate algorithm=13 ksk=no zsk=yes
  keymgr tld ds | grep '13 2' > /var/lib/knot/keys/ds.tld   # for root zone
  exit

mkdir files/knot-fakeroot
mkdir files/knot-fakeroot/zones files/knot-fakeroot/journal
vim files/knot-fakeroot/knot.conf
(using the same docker image as knot-signer so no build here)
docker run --rm -it --entrypoint bash -v ./files/knot-fakeroot/knot.conf:/etc/knot/knot.conf:ro -v ./files/knot-fakeroot/keys:/var/lib/knot/keys:rw -v ./files/knot-fakeroot/zones:/var/lib/knot/zones:rw -v ./files/knot-fakeroot/journal:/var/lib/knot/journal:rw knotd-stiab:latest
  chown --recursive knot:knot /var/lib/knot
  keymgr . generate algorithm=13 ksk=yes zsk=no
  keymgr . generate algorithm=13 ksk=no zsk=yes
  keymgr . ds | grep '13 2' > /var/lib/knot/keys/ds.root   # for unbound trust anchor
  for KEYID in `keymgr . list | awk '{print $2}'`; do keymgr . dnskey $KEYID; done > /var/lib/knot/keys/dnskey.root   # for root zone
  exit
curl https://www.internic.net/domain/root.zone > files/signed-root.zone
cp files/signed-root.zone files/unsigned-root.zone
NOTE: leaving arpa. for 172.20.0.0/24 alone.
vim files/unsigned-root.zone
:g/IN\sRRSIG/d                                           # remove all RRSIGs
:g/IN\sNSEC/d                                            # remove all NSEC
:g/^\.\s.*IN\sZONEMD/d                                   # remove root's ZONEMD
:g/^\.\s.*IN\sDNSKEY/d                                   # remove root's DNSKEY (so need to supply our own)
:%s/a.root-servers.net./a.root-servers.tld./             # avoid confusion by using own tld
:g/^a.root-servers.tld.\s.*AAAA/d                        # no ipv6 at the moment...
:g/^\.\s.*\sIN\sNS\s.\.root-servers\.net\.$/d            # remove all root-servers.net NS's so only a.root-servers.tld left
:%s/nstld.verisign-grs.com./hostmaster./                 # replace SOA mail address to avoid confusion
:%s/1800 900 604800 86400/900 60 3600 60/                # replace SOA timings
:%s/^\(a.root-servers.tld.\s.*\sA\s\).*/\1172.20.0.13/   # replace ipv4 address of a.root-servers.tld (formally a.root-servers.net)
:2
:r files/knot-fakeroot/keys/dnskey.root
:4
o
tld.                    172800  IN      NS      ns1.nic.tld.
tld.                    86400   IN      DS      54231 13 2 b2c729851fbf44105868c94fbfd98a79cc63992f63acd03d3fd25b873dd294b5 # files/knot-signer/keys/ds.root
ns1.nic.tld.            172800  IN      A       172.20.0.14

cp files/unsigned-root.zone files/knot-fakeroot/zones/root.zone


mkdir files/nsd-validator
mkdir files/nsd-validator/zones files/nsd-validator/keys
vim files/nsd-validator/nsd.conf   # Note: zones and key/cert files under /var/lib/stiab/
(files/nsd-validator/zones/tld.zone is created automatically after notify from knot-signer)
(using the same docker image as nsd-zoneloader so no build here)
docker run --rm -it --entrypoint bash -v ./files/nsd-validator/nsd.conf:/etc/nsd/nsd.conf:ro -v ./files/nsd-validator/keys:/var/lib/stiab/keys:rw nsd-stiab:latest
  nsd-control-setup -d /var/lib/stiab/keys/
  exit
TODO: actual validation of the signed zone


mkdir files/nsd-dister
mkdir files/nsd-dister/zones files/nsd-dister/keys
vim files/nsd-dister/nsd.conf   # Note: zones and key/cert files under /var/lib/stiab/
(files/nsd-dister/zones/tld.zone is created automatically after notify from nsd-validator)
(using the same docker image as nsd-zoneloader so no build here)
docker run --rm -it --entrypoint bash -v ./files/nsd-dister/nsd.conf:/etc/nsd/nsd.conf:ro -v ./files/nsd-dister/keys:/var/lib/stiab/keys:rw nsd-stiab:latest
  nsd-control-setup -d /var/lib/stiab/keys/
  exit


mkdir files/unbound-recursor
mkdir files/unbound-recursor/conf
files/unbound-recursor/conf/fake-root.hints
files/unbound-recursor/conf/unbound.conf
files/unbound-recursor/conf/unbound.conf.d
files/unbound-recursor/conf/unbound.conf.d/remote-control.conf
files/unbound-recursor/conf/unbound.conf.d/base.conf  # trust-anchor: see: cat files/knot-fakeroot/keys/dnskey.root | grep '.\sDNSKEY\s257.*'
docker build -t unbound-stiab:latest -f dockerfiles/Dockerfile.unbound . &&  docker system prune -f && docker buildx prune -f
docker run --rm -it --entrypoint bash -v ./files/unbound-recursor/conf:/etc/unbound/:rw unbound-stiab:latest
   unbound-control-setup


mkdir files/dns-client
mkdir files/dns-client/conf files/dns-client/results
cat files/knot-fakeroot/keys/dnskey.root | grep '.\sDNSKEY\s257.*' > files/dns-client/conf/root.key
vim files/dns-client/conf/root.key-delv  # same root.key, but differently packaged
cp files/unbound-recursor/conf/fake-root.hints files/dns-client/conf/
docker build -t dnsclient-stiab:latest -f dockerfiles/Dockerfile.dnsclient . &&  docker system prune -f && docker buildx prune -f
(a docker run serves no purpose here, after docker compose up -d do your dig/drill/delv-thang (see below))

TODO: dnsviz



After creation of config and keys, tar-gzip the whole stiab directory


deploy
--------------------------------------------------------------------------------------------------
tar xzf stiab.tgz / git clone https://github.com/niek-sidn/stiab.git
cd stiab
DID YOU BUILD THE DOCKER IMAGES?
docker compose up -d
docker compose logs

prove it works
--------------------------------------------------------------------------------------------------
docker exec -it stiab-dns-client-1 bash
dig +multi +dnssec soa . @172.20.0.15
dig +multi +dnssec soa tld. @172.20.0.15
dig +multi +dnssec soa sidn.nl. @172.20.0.15
dig +multi +dnssec soa doesntexist.tld. @172.20.0.15
dig +multi +dnssec soa brokendnssec.net. @172.20.0.15
dig +multi +dnssec soa brokendnssec.net. @172.20.0.15 +cdflag
drill -S tld. @172.20.0.15 soa
drill -k /var/lib/dns/conf/root.key -r /var/lib/dns/conf/fake-root.hints -T tld. @172.20.0.15 soa
drill -k /var/lib/dns/conf/root.key -r /var/lib/dns/conf/fake-root.hints -T sidn.nl. @172.20.0.15 soa
drill -k /var/lib/dns/conf/root.key -r /var/lib/dns/conf/fake-root.hints -T doesntexist.tld. @172.20.0.15 soa
drill -k /var/lib/dns/conf/root.key -r /var/lib/dns/conf/fake-root.hints -T brokendnssec.net. @172.20.0.15 soa
delv +vtrace -a /var/lib/dns/conf/root.key-delv @172.20.0.15 sidn.nl soa
delv +vtrace -a /var/lib/dns/conf/root.key-delv @172.20.0.15 tld. soa
delv +vtrace -a /var/lib/dns/conf/root.key-delv @172.20.0.15 doesntexist.tld. soa
delv +vtrace -a /var/lib/dns/conf/root.key-delv @172.20.0.15 brokendnssec.net. soa +cdflag

docker compose down


