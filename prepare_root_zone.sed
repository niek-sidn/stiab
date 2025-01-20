/IN\sRRSIG/d
/IN\sNSEC/d
/^\.\s.*IN\sZONEMD/d
/^\.\s.*IN\sDNSKEY/d
s/a.root-servers.net./a.root-servers.tld./
/^a.root-servers.tld.\s.*AAAA/d
/^\.\s.*\sIN\sNS\s.\.root-servers\.net\.$/d
s/nstld.verisign-grs.com./hostmaster./
s/1800 900 604800 86400/900 60 3600 60/
s/^\(a.root-servers.tld.\s.*\sA\s\).*/\1172.20.0.13/
/^\.\s.*IN\sNS/a .			60	IN	TXT	"This DNS root domain does not really exist"
/^\.\s.*IN\sNS/e sed 's/^\. DNSKEY /\.			1800	IN	DNSKEY	/' files/knot-fakeroot/keys/dnskey.root
/^\.\s.*IN\sNS/a tld.			172800	IN	NS	ns1.nic.tld.
/^\.\s.*IN\sNS/a tld.			86400	IN	DS	54231 13 2 b2c729851fbf44105868c94fbfd98a79cc63992f63acd03d3fd25b873dd294b5
/^\.\s.*IN\sNS/a ns1.nic.tld.		172800	IN	A	172.20.0.14
