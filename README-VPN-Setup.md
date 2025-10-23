# VPN Gateway - StrongSwan + OpenVPN

Script automatizado para configuração de gateway VPN combinando StrongSwan (IPsec) e OpenVPN em ambiente AWS.

## ⚠️ IMPORTANTE - CONFIGURAÇÃO ANTES DO USO

**ESTE SCRIPT CONTÉM DADOS GENÉRICOS. VOCÊ DEVE PERSONALIZAR ANTES DE USAR:**

### 1. Alterar Chave PSK
Edite `/etc/ipsec.secrets` após a instalação e substitua:
```
"ALTERE_ESTA_CHAVE_SECRETA_123"
```
Por uma chave forte e única.

### 2. Configurar IPs dos Clientes
Edite `/etc/ipsec.conf` e substitua os IPs genéricos pelos reais:
- `203.0.113.10` → IP real do cliente1
- `203.0.113.20` → IP real do cliente2
- etc.

### 3. Configurar Redes dos Clientes
Ajuste as subnets conforme sua topologia:
- `192.168.1.0/24` → Rede real do cliente1
- `172.16.1.0/24` → Rede real do cliente2
- etc.

## 🚀 Instalação

```bash
# Baixar o script
wget https://raw.githubusercontent.com/SEU_USUARIO/SEU_REPO/main/vpn-strongswan-aws-generic.sh

# Dar permissão de execução
chmod +x vpn-strongswan-aws-generic.sh

# Executar como root
sudo ./vpn-strongswan-aws-generic.sh
```

## 📋 Pré-requisitos AWS

1. **EC2 Instance**: Ubuntu 20.04+ com IP público
2. **Security Group**: Liberar portas 500, 4500, 1194/UDP
3. **Source/Destination Check**: Desabilitar na instância EC2
4. **IAM**: Permissões para modificar route tables (se necessário)

## 🔧 Configuração Pós-Instalação

### StrongSwan (IPsec)
1. Editar `/etc/ipsec.conf` com IPs reais
2. Editar `/etc/ipsec.secrets` com chaves reais
3. Reiniciar: `systemctl restart strongswan-starter`

### OpenVPN
- Certificados gerados em: `/root/client-configs/`
- Distribuir arquivos `.ovpn` para usuários

## 🌐 Topologia de Rede

```
Internet
    |
[AWS VPN Gateway]
    |
├── StrongSwan (IPsec) ── Cliente1 (192.168.1.0/24)
├── StrongSwan (IPsec) ── Cliente2 (172.16.1.0/24)
├── StrongSwan (IPsec) ── Cliente3 (172.20.1.0/24)
├── StrongSwan (IPsec) ── Cliente4 (172.24.1.0/24)
├── StrongSwan (IPsec) ── Cliente5 (10.10.1.0/24)
├── StrongSwan (IPsec) ── Cliente6 (10.20.1.0/24)
└── OpenVPN (SSL) ────── Usuários remotos (10.8.0.0/24)
```

## 🔍 Troubleshooting

### Verificar Status
```bash
systemctl status strongswan-starter
systemctl status openvpn-server@server
```

### Logs
```bash
# StrongSwan
journalctl -u strongswan-starter -f

# OpenVPN
tail -f /var/log/openvpn/openvpn.log
```

### Testar Conectividade
```bash
# Verificar túneis IPsec
ipsec status

# Verificar clientes OpenVPN
cat /var/log/openvpn/openvpn-status.log
```

## 🛡️ Segurança

- ✅ Criptografia AES-256 (OpenVPN) e AES-128 (IPsec)
- ✅ Autenticação SHA-256
- ✅ Certificados PKI para OpenVPN
- ✅ Chaves pré-compartilhadas para IPsec
- ✅ Firewall configurado automaticamente

## 📝 Licença

MIT License - Use livremente, mas por sua conta e risco.

## ⚠️ Disclaimer

Este script é fornecido "como está". Teste em ambiente de desenvolvimento antes de usar em produção.