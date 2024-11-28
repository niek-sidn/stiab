## Host
    apt-get update && apt-get upgrade -y && apt-get install -y git ca-certificates curl \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc \
    && chmod a+r /etc/apt/keyrings/docker.asc \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update && apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
    && systemctl enable --now docker \
    && git clone https://github.com/niek-sidn/stiab.git \
    && cd stiab

## Host
    docker compose up -d --build
    docker exec -it stiab-dns-client-1 bash

## Proof
    dig +multi +dnssec +cdflag soa sidn.nl. @172.20.0.15 | grep --color -e 'flags:.*cd' -e '^[[:space:]]*[[:digit:]]* [[:digit:]]* [[:digit:]]* .*\.$' -e '.*serial$' -e 'NOERROR' -e 'NXDOMAIN,' -e 'SERVFAIL' -e '^'
    dig +multi +dnssec +cdflag soa tld. @172.20.0.15 | grep --color -e 'flags:.*cd' -e '^[[:space:]]*[[:digit:]]* [[:digit:]]* [[:digit:]]* .*\.$' -e '.*serial$' -e 'NOERROR' -e 'NXDOMAIN,' -e 'SERVFAIL' -e '^'
    dig +multi +dnssec +cdflag soa sidn.tld. @172.20.0.15 | grep --color -e 'flags:.*cd' -e '^[[:space:]]*[[:digit:]]* [[:digit:]]* [[:digit:]]* .*\.$' -e '.*serial$' -e 'NOERROR' -e 'NXDOMAIN,' -e 'SERVFAIL' -e '^'
    
    drill -S sidn.tld. @172.20.0.15 soa
    drill -k /var/lib/dns/conf/root.key -r /var/lib/dns/conf/fake-root.hints -T sidn.tld. @172.20.0.15 soa |  grep --color -e '\[[BUTS]\]' -e '^'
    
    delv +vtrace +multi -a /var/lib/dns/conf/root.key-delv @172.20.0.15 sidn.tld. soa +cdflag 2>&1 | grep --color -e 'fully validated' -e '^[[:space:]]*[[:digit:]]* [[:digit:]]* [[:digit:]]* .*tld\.$' -e 'negative response' -e '.*serial$' -e 'failed' -e 'unsigned answer' -e 'insecurity proof failed' -e '^'
