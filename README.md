# 🛡️ AWS VPN Gateway Automation (StrongSwan IPsec + OpenVPN)

Solução automatizada de infraestrutura para provisionamento e configuração de **Gateway VPN Híbrido na AWS (EC2)**, combinando túneis Site-to-Site com **StrongSwan (IPsec)** e conexões para usuários remotos (Point-to-Site) via **OpenVPN**, acompanhada de script em Python para inicialização e conexão sob demanda.

---

## 🚀 Funcionalidades

- **Gateway VPN Multi-Propósito:**
  - 🏢 **Site-to-Site (IPsec / StrongSwan):** Conexão segura entre matriz, filiais e parceiros de negócio (múltiplas subnets configuráveis).
  - 💻 **Point-to-Site (SSL VPN / OpenVPN):** Acesso remoto criptografado para desenvolvedores e colaboradores em home office.
- **Automação Local Sob Demanda (`script-inicia-ec2-vpn.py`):**
  - Script em Python que se comunica com a AWS CLI para ligar a instância EC2 apenas quando for utilizada (economia de custos).
  - Captura automaticamente o IP público alocado dinamicamente pela AWS.
  - Inicia uma sessão SSH interativa direta no seu terminal.
- **Firewall & Roteamento Automatizados:**
  - Ativação de `ip_forwarding` no Kernel Linux.
  - Regras de `iptables` para MASQUERADE/NAT entre as subnets dos clientes e a rede interna da AWS.
- **Infraestrutura PKI Embutida:** Geração automática da autoridade certificadora (CA) e perfis de clientes `.ovpn` para OpenVPN.

---

## 🛠️ Tecnologias e Protocolos

- **Cloud Provider:** Amazon Web Services (AWS EC2 - Ubuntu 20.04/22.04+)
- **IPsec Daemon:** StrongSwan
- **SSL VPN:** OpenVPN Server + Easy-RSA
- **Linguagens de Automação:** Bash (Shell Script) & Python 3 (Boto3/Subprocess com AWS CLI)
- **Criptografia:** AES-256 (OpenVPN) / AES-128 (IPsec), HMAC-SHA256, DH Group 14

---

## 📂 Estrutura do Repositório

```text
aws-vpn-gateway-automation/
├── vpn-strongswan-aws-generic.sh  # Script shell executado na EC2 para instalar e configurar toda a VPN
├── script-inicia-ec2-vpn.py       # Script Python para ligar a EC2 via AWS CLI e abrir SSH localmente
├── .gitignore                    # Proteção contra commit acidental de chaves .pem, .ovpn ou segredos
└── README.md                     # Documentação completa do projeto
```

---

## 🌐 Topologia de Rede do Gateway

```text
                 ┌────────────────────────────────┐
                 │       Internet / Clientes      │
                 └──────────────┬─────────────────┘
                                │
               [ AWS EC2 VPN Gateway (Ubuntu) ]
                                │
   ┌────────────────────────────┼────────────────────────────┐
   │                            │                            │
[Site-to-Site IPsec]    [Site-to-Site IPsec]       [OpenVPN Road Warrior]
   │                            │                            │
Filial 1: 192.168.1.0/24    Filial 2: 172.16.1.0/24     Usuários: 10.8.0.0/24
```

---

## ⚙️ Pré-requisitos na AWS

1. **Instância EC2:** Ubuntu Server com IP Público (ou Elastic IP associado).
2. **Security Group:**
   - `UDP 500` (IKE IPsec)
   - `UDP 4500` (IPsec NAT-Traversal)
   - `UDP 1194` (OpenVPN Server)
   - `TCP 22` (Acesso administrativo SSH)
3. **Source/Destination Check:** **Desabilitado** na placa de rede da instância EC2 (obrigatório para instâncias que atuam como roteador/gateway).
4. **AWS Route Tables:** Rota na VPC direcionando o tráfego das subnets locais dos clientes para o Network Interface ID da EC2 da VPN.

---

## 🚀 Como Instalar e Configurar o Gateway

### 1. No Servidor AWS EC2

Conecte-se na sua instância EC2 e execute o script de provisionamento:

```bash
# Baixar o script de instalacao
wget https://raw.githubusercontent.com/igorpaiva26/aws-vpn-gateway-automation/main/vpn-strongswan-aws-generic.sh

# Conceder permissao de execucao
chmod +x vpn-strongswan-aws-generic.sh

# Executar como root
sudo ./vpn-strongswan-aws-generic.sh
```

---

### 2. Personalização das Configurações de Segurança

⚠️ **Importante:** O script utiliza dados genéricos de demonstração. Você deve substituir pelos dados reais do seu ambiente:

#### A. Chaves Pré-Compartilhadas (PSK) do IPsec
Edite o arquivo `/etc/ipsec.secrets`:
```text
"SUA_CHAVE_SECRETA_FORTE_AQUI"
```

#### B. IPs Públicos e Redes Locais das Filiais
Edite o arquivo `/etc/ipsec.conf` e configure os blocos de cada filial:
- Substitua os IPs dos gateways remotos (`right=203.0.113.x`).
- Substitua as subnets remotas (`rightsubnet=192.168.x.x/24`).

Reinicie o StrongSwan:
```bash
sudo systemctl restart strongswan-starter
```

#### C. Distribuição de Perfis OpenVPN
Os arquivos de configuração dos clientes remotos (`.ovpn`) com certificados embutidos são gerados no diretório:
```bash
/root/client-configs/
```
Copie com segurança os arquivos `.ovpn` para os usuários finais utilizarem no cliente OpenVPN Connect.

---

## 💻 Automação Local (Iniciar EC2 Sob Demanda)

No seu computador local (Windows ou Linux), você pode usar o script **`script-inicia-ec2-vpn.py`** para evitar custos desnecessários mantendo a EC2 ligada 24/7:

1. Configure a [AWS CLI](https://aws.amazon.com/cli/) com `aws configure`.
2. Edite as variáveis no início do script `script-inicia-ec2-vpn.py`:
   ```python
   INSTANCE_ID = "i-0123456789abcdef0"
   KEY_PATH = r"C:\Users\seu-usuario\.ssh\sua-chave.pem"
   SSH_USER = "ubuntu"
   REGION = "us-east-1"
   ```
3. Execute o script:
   ```bash
   python script-inicia-ec2-vpn.py
   ```
4. O script iniciará a instância na AWS, aguardará a prontidão, detectará o novo IP público alocado e abrirá a sessão SSH automaticamente.

---

## 🔍 Troubleshooting e Diagnóstico

### Checar Status dos Serviços:
```bash
# Status do StrongSwan (IPsec)
sudo ipsec status
sudo systemctl status strongswan-starter

# Status do OpenVPN
sudo systemctl status openvpn-server@server
cat /var/log/openvpn/openvpn-status.log
```

### Acompanhar Logs em Tempo Real:
```bash
# Logs do IPsec
sudo journalctl -u strongswan-starter -f

# Logs do OpenVPN
sudo tail -f /var/log/openvpn/openvpn.log
```

---

## 👤 Autor

Desenvolvido por **[Igor Paiva](https://github.com/igorpaiva26)**.
