#!/bin/sh /etc/rc.common
START=99

start() {
    ss-redir -c /etc/shadowsocks-libev/config.json -b 0.0.0.0 -l 1080 -f /var/run/ss-redir.pid
    sleep 2
    ipset create vpn_list hash:ip hashsize 65536 maxelem 131072 -exist
    ipset flush vpn_list
    cat /etc/shadowsocks-libev/community.lst /etc/shadowsocks-libev/list-general.txt /etc/shadowsocks-libev/list-google.txt /etc/shadowsocks-libev/my-domains.txt 2>/dev/null | grep -v '^#' | grep -v '^$' | sort -u | awk '{print "ipset=/"$0"/vpn_list"}' > /tmp/dnsmasq.d/vpn-whitelist.conf
    /etc/init.d/dnsmasq restart
    iptables -t nat -N SS_REDIR 2>/dev/null
    iptables -t nat -F SS_REDIR
    iptables -t nat -D PREROUTING -p tcp -j SS_REDIR 2>/dev/null
    iptables -t nat -A SS_REDIR -d __SERVER_IP__ -j RETURN
    iptables -t nat -A SS_REDIR -d 0.0.0.0/8 -j RETURN
    iptables -t nat -A SS_REDIR -d 10.0.0.0/8 -j RETURN
    iptables -t nat -A SS_REDIR -d 127.0.0.0/8 -j RETURN
    iptables -t nat -A SS_REDIR -d 169.254.0.0/16 -j RETURN
    iptables -t nat -A SS_REDIR -d 172.16.0.0/12 -j RETURN
    iptables -t nat -A SS_REDIR -d 192.168.0.0/16 -j RETURN
    iptables -t nat -A SS_REDIR -d 224.0.0.0/4 -j RETURN
    iptables -t nat -A SS_REDIR -d 240.0.0.0/4 -j RETURN
    iptables -t nat -A SS_REDIR -m set --match-set vpn_list dst -p tcp -j REDIRECT --to-ports 1080
    iptables -t nat -A PREROUTING -p tcp -j SS_REDIR
    iptables -t nat -A PREROUTING -p udp --dport 53 ! -d 192.168.8.1 -j DNAT --to-destination 192.168.8.1:53
    iptables -t nat -A PREROUTING -p tcp --dport 53 ! -d 192.168.8.1 -j DNAT --to-destination 192.168.8.1:53
    iptables -I FORWARD -p udp -m set --match-set vpn_list dst -j DROP
}

stop() {
    killall ss-redir 2>/dev/null
    iptables -t nat -D PREROUTING -p tcp -j SS_REDIR 2>/dev/null
    iptables -t nat -F SS_REDIR 2>/dev/null
    iptables -t nat -X SS_REDIR 2>/dev/null
    iptables -t nat -D PREROUTING -p udp --dport 53 ! -d 192.168.8.1 -j DNAT --to-destination 192.168.8.1:53 2>/dev/null
    iptables -t nat -D PREROUTING -p tcp --dport 53 ! -d 192.168.8.1 -j DNAT --to-destination 192.168.8.1:53 2>/dev/null
    iptables -D FORWARD -p udp -m set --match-set vpn_list dst -j DROP 2>/dev/null
    ipset flush vpn_list 2>/dev/null
    rm -f /tmp/dnsmasq.d/vpn-whitelist.conf
    /etc/init.d/dnsmasq restart
}
