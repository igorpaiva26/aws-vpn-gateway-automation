#!/bin/bash

# Script VPN Gateway - StrongSwan + OpenVPN
# Versão genérica para compartilhamento público

set -e

echo "=== Instalação VPN Gateway (StrongSwan + OpenVPN) ==="

# Verificar se é root
if [[ $EUID -ne 0 ]]; then
   echo "Execute como root: sudo $0"
   exit 1
fi

# Atualizar sistema
echo "Atualizando sistema..."
apt update && apt upgrade -y

# Instalar pacotes necessários
echo "Instalando pacotes..."
apt install -y strongswan strongswan-pki libcharon-extra-plugins openvpn easy-rsa iptables-persistent curl

# Habilitar IP forwarding
echo "Habilitando IP forwarding..."
echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
echo 'net.ipv4.conf.all.accept_redirects=0' >> /etc/sysctl.conf
echo 'net.ipv4.conf.all.send_redirects=0' >> /etc/sysctl.conf
sysctl -p

# Obter IP público atual
PUBLIC_IP=$(curl -s ifconfig.me)
PRIVATE_IP=$(hostname -I | awk '{print $1}')

echo "IP Público detectado: $PUBLIC_IP"
echo "IP Privado detectado: $PRIVATE_IP"

# Configurar StrongSwan
cat > /etc/ipsec.conf << EOF
config setup
    charondebug="ike 2, knl 2, cfg 2"
    uniqueids=no

conn %default
    ikelifetime=8h
    keylife=8h
    rekeymargin=3m
    keyingtries=3
    keyexchange=ikev1
    authby=secret
    ike=aes128-sha1-modp1024!
    esp=aes128-sha1-modp1024!
    dpdaction=restart
    dpddelay=120s

# Túnel cliente1
conn cliente1
    left=$PRIVATE_IP
    leftid=$PUBLIC_IP
    leftsubnet=192.168.100.0/24
    right=203.0.113.10
    rightsubnet=192.168.1.0/24
    auto=start

# Túnel cliente2
conn cliente2
    left=$PRIVATE_IP
    leftid=$PUBLIC_IP
    leftsubnet=192.168.100.0/24
    right=203.0.113.20
    rightsubnet=172.16.1.0/24
    auto=start

# Túnel cliente3
conn cliente3
    left=$PRIVATE_IP
    leftid=$PUBLIC_IP
    leftsubnet=192.168.100.0/24
    right=203.0.113.30
    rightsubnet=172.20.1.0/24
    auto=start

# Túnel cliente4
conn cliente4
    left=$PRIVATE_IP
    leftid=$PUBLIC_IP
    leftsubnet=192.168.100.0/24
    right=203.0.113.40
    rightsubnet=172.24.1.0/24
    auto=start

# Túnel cliente5
conn cliente5
    left=$PRIVATE_IP
    leftid=$PUBLIC_IP
    leftsubnet=192.168.100.0/24
    right=203.0.113.50
    rightsubnet=10.10.1.0/24
    auto=start

# Túnel cliente6
conn cliente6
    left=$PRIVATE_IP
    leftid=$PUBLIC_IP
    leftsubnet=192.168.100.0/24
    right=203.0.113.60
    rightsubnet=10.20.1.0/24
    auto=start
EOF

# Configurar chaves - ALTERE A CHAVE ANTES DE USAR EM PRODUÇÃO
cat > /etc/ipsec.secrets << EOF
# Chaves para túneis IPsec - ALTERE ESTAS CHAVES ANTES DE USAR
$PRIVATE_IP 203.0.113.10 : PSK "ALTERE_ESTA_CHAVE_SECRETA_123"
$PRIVATE_IP 203.0.113.20 : PSK "ALTERE_ESTA_CHAVE_SECRETA_123"
$PRIVATE_IP 203.0.113.30 : PSK "ALTERE_ESTA_CHAVE_SECRETA_123"
$PRIVATE_IP 203.0.113.40 : PSK "ALTERE_ESTA_CHAVE_SECRETA_123"
$PRIVATE_IP 203.0.113.50 : PSK "ALTERE_ESTA_CHAVE_SECRETA_123"
$PRIVATE_IP 203.0.113.60 : PSK "ALTERE_ESTA_CHAVE_SECRETA_123"
EOF

chmod 600 /etc/ipsec.secrets

# Configurar OpenVPN
echo "Configurando OpenVPN..."
mkdir -p /etc/openvpn/server
cd /usr/share/easy-rsa

# Configurar PKI
./easyrsa init-pki
echo "vpn-gateway" | ./easyrsa build-ca nopass
./easyrsa gen-req server nopass
echo "yes" | ./easyrsa sign-req server server
./easyrsa gen-dh
openvpn --genkey --secret /etc/openvpn/server/ta.key

# Copiar certificados
cp pki/ca.crt /etc/openvpn/server/
cp pki/issued/server.crt /etc/openvpn/server/
cp pki/private/server.key /etc/openvpn/server/
cp pki/dh.pem /etc/openvpn/server/

# Configurar servidor OpenVPN
cat > /etc/openvpn/server/server.conf << EOF
port 1194
proto udp
dev tun
ca ca.crt
cert server.crt
key server.key
dh dh.pem
tls-auth ta.key 0
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist /var/log/openvpn/ipp.txt
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
keepalive 10 120
cipher AES-256-CBC
auth SHA256
user nobody
group nogroup
persist-key
persist-tun
status /var/log/openvpn/openvpn-status.log
log-append /var/log/openvpn/openvpn.log
verb 3
explicit-exit-notify 1
push "route 192.168.1.0 255.255.255.0"
push "route 172.16.1.0 255.255.255.0"
push "route 172.20.1.0 255.255.255.0"
push "route 172.24.1.0 255.255.255.0"
push "route 10.10.1.0 255.255.255.0"
push "route 10.20.1.0 255.255.255.0"
EOF

mkdir -p /var/log/openvpn

# Configurar iptables
echo "Configurando firewall..."

# Limpar regras
iptables -F
iptables -t nat -F

# INPUT - Liberar portas VPN
iptables -A INPUT -p udp --dport 1194 -j ACCEPT
iptables -A INPUT -p udp --dport 500 -j ACCEPT
iptables -A INPUT -p udp --dport 4500 -j ACCEPT
iptables -A INPUT -p esp -j ACCEPT

# NAT para OpenVPN
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE

# FORWARD para OpenVPN
iptables -A FORWARD -i tun0 -o eth0 -j ACCEPT
iptables -A FORWARD -i eth0 -o tun0 -m state --state RELATED,ESTABLISHED -j ACCEPT

# FORWARD e NAT para redes dos clientes
iptables -A FORWARD -s 10.8.0.0/24 -d 192.168.1.0/24 -j ACCEPT
iptables -A FORWARD -s 192.168.1.0/24 -d 10.8.0.0/24 -j ACCEPT
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -d 192.168.1.0/24 -j MASQUERADE

iptables -A FORWARD -s 10.8.0.0/24 -d 172.16.1.0/24 -j ACCEPT
iptables -A FORWARD -s 172.16.1.0/24 -d 10.8.0.0/24 -j ACCEPT
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -d 172.16.1.0/24 -j MASQUERADE

iptables -A FORWARD -s 10.8.0.0/24 -d 172.20.1.0/24 -j ACCEPT
iptables -A FORWARD -s 172.20.1.0/24 -d 10.8.0.0/24 -j ACCEPT
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -d 172.20.1.0/24 -j MASQUERADE

iptables -A FORWARD -s 10.8.0.0/24 -d 172.24.1.0/24 -j ACCEPT
iptables -A FORWARD -s 172.24.1.0/24 -d 10.8.0.0/24 -j ACCEPT
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -d 172.24.1.0/24 -j MASQUERADE

iptables -A FORWARD -s 10.8.0.0/24 -d 10.10.1.0/24 -j ACCEPT
iptables -A FORWARD -s 10.10.1.0/24 -d 10.8.0.0/24 -j ACCEPT
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -d 10.10.1.0/24 -j MASQUERADE

iptables -A FORWARD -s 10.8.0.0/24 -d 10.20.1.0/24 -j ACCEPT
iptables -A FORWARD -s 10.20.1.0/24 -d 10.8.0.0/24 -j ACCEPT
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -d 10.20.1.0/24 -j MASQUERADE

# IPsec
iptables -A FORWARD -m policy --pol ipsec --dir in -j ACCEPT
iptables -A FORWARD -m policy --pol ipsec --dir out -j ACCEPT
iptables -t nat -A POSTROUTING -m policy --pol ipsec --dir out -j ACCEPT

# Salvar regras
iptables-save > /etc/iptables/rules.v4

# Gerar certificados de usuário
echo "Gerando certificados de usuário..."
mkdir -p /root/client-configs

for i in {1..5}; do
    cd /usr/share/easy-rsa
    ./easyrsa gen-req user$i nopass
    echo "yes" | ./easyrsa sign-req client user$i
    
    # Criar arquivo .ovpn
    cat > /root/client-configs/user$i.ovpn << EOF
client
dev tun
proto udp
remote $PUBLIC_IP 1194
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-CBC
auth SHA256
verb 3
<ca>
$(cat /etc/openvpn/server/ca.crt)
</ca>
<cert>
$(cat /usr/share/easy-rsa/pki/issued/user$i.crt)
</cert>
<key>
$(cat /usr/share/easy-rsa/pki/private/user$i.key)
</key>
<tls-auth>
$(cat /etc/openvpn/server/ta.key)
</tls-auth>
key-direction 1
EOF
done

# Iniciar serviços
echo "Iniciando serviços..."
systemctl enable strongswan-starter
systemctl enable openvpn-server@server
systemctl start strongswan-starter
systemctl start openvpn-server@server

# Aguardar serviços
sleep 10

echo "=== INSTALAÇÃO CONCLUÍDA ==="
echo "✅ IP Público: $PUBLIC_IP"
echo "✅ IP Privado: $PRIVATE_IP"
echo "✅ OpenVPN: Porta 1194/UDP"
echo "✅ StrongSwan: Portas 500/4500/UDP + ESP"
echo "✅ Certificados: /root/client-configs/"
echo ""
echo "🔧 PRÓXIMOS PASSOS:"
echo "1. ALTERAR A CHAVE PSK em /etc/ipsec.secrets"
echo "2. ALTERAR IPs dos clientes em /etc/ipsec.conf"
echo "3. Desabilitar Source/Destination Check na EC2"
echo "4. Configurar Security Group (1194, 500, 4500/UDP)"
echo "5. Configurar equipamentos dos clientes com IP: $PUBLIC_IP"
echo "6. Distribuir arquivos .ovpn para usuários"
echo ""
echo "📊 STATUS DOS SERVIÇOS:"
systemctl is-active strongswan-starter && echo "✅ StrongSwan: Ativo" || echo "❌ StrongSwan: Inativo"
systemctl is-active openvpn-server@server && echo "✅ OpenVPN: Ativo" || echo "❌ OpenVPN: Inativo"