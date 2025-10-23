import subprocess
import json
import time
import sys

# ==============================================================================
# 1. CONFIGURAÇÕES OBRIGATÓRIAS (AJUSTE AQUI)
# ==============================================================================
# ID da sua instância EC2 que você quer ligar/conectar
INSTANCE_ID = "sua instancia aqui" 

# Caminho COMPLETO para a sua chave privada .pem no Windows (use barras invertidas ou o 'r' antes da string)
# EX: KEY_PATH = r"C:\Users\SEU_USUARIO\.ssh\minha-chave.pem"
KEY_PATH = r"C:\Users\usuarioLocal\.ssh\private_key.pem"

# Usuário de conexão (geralmente 'ubuntu', 'ec2-user' ou 'centos')
SSH_USER = "ubuntu" 

# Região da sua instância (ex: us-east-1, sa-east-1).
REGION = "us-east-1" 

# Tempo de espera após ligar a VM (em segundos)
WAIT_TIME_SECONDS = 20

# ==============================================================================
# 2. FUNÇÕES PRINCIPAIS
# ==============================================================================

def start_instance():
    """Liga a instância EC2 e espera o tempo definido para inicialização."""
    print(f"\n[1] Iniciando instância {INSTANCE_ID}...")
    try:
        command = [
            'aws', 'ec2', 'start-instances', 
            '--instance-ids', INSTANCE_ID, 
            '--region', REGION
        ]
        
        # Executa o comando, suprimindo o output padrão para manter a interface limpa
        subprocess.run(command, check=True, stdout=subprocess.DEVNULL)
        
        print(f"Instância {INSTANCE_ID} iniciada com sucesso. Aguardando {WAIT_TIME_SECONDS} segundos...")
        time.sleep(WAIT_TIME_SECONDS)
        print("VM está ligada e pronta.")
        return True
    except subprocess.CalledProcessError:
        print(f"ERRO ao iniciar a instância. Verifique as permissões do usuário 'adapter'.")
        return False
    except FileNotFoundError:
        print("ERRO: O AWS CLI não foi encontrado. Instale ou verifique o PATH.")
        return False


def connect_via_ssh(instance_id=INSTANCE_ID):
    """Obtém o IP público e inicia a conexão SSH em uma nova janela do CMD."""
    print(f"\n[2] Buscando IP público para {instance_id} e conectando...")
    
    query = "Reservations[0].Instances[0].PublicIpAddress"
    
    try:
        # 1. Busca o IP Público
        cli_command = [
            'aws', 'ec2', 'describe-instances',
            '--instance-ids', instance_id,
            '--region', REGION,
            '--query', query,
            '--output', 'text'
        ]
        
        result = subprocess.run(cli_command, capture_output=True, text=True, check=True)
        public_ip = result.stdout.strip()
        
        if public_ip and public_ip != "None":
            # 2. Constrói o comando SSH completo
            # Note: Usamos barras simples no comando SSH, pois ele será executado DENTRO do novo CMD.
            # O comando 'start cmd /k' é usado para abrir uma nova janela e manter ela aberta (/k).
            ssh_command = f'ssh -i "{KEY_PATH}" {SSH_USER}@{public_ip}'
            full_command = f'start cmd /k "{ssh_command}"'

            # 3. Executa o comando em uma nova janela (subprocess.Popen para não travar o script principal)
            subprocess.Popen(full_command, shell=True) 

            print("\n=======================================================")
            print(f"Conexão SSH iniciada em uma NOVA JANELA para o IP: {public_ip}")
            print("=======================================================\n")
            return True
        else:
            print("AVISO: IP público não encontrado. A VM pode ainda estar inicializando ou não ter um IP público. Tente rodar '1' novamente, ou tente a opção '2' novamente em alguns segundos.")
            return False
            
    except subprocess.CalledProcessError:
        print("ERRO ao buscar o IP. Verifique o ID da instância.")
        return False

# ==============================================================================
# 3. INTERFACE DE COMANDO COM LOOP INTERATIVO
# ==============================================================================

def display_menu():
    """Exibe o menu de opções."""
    print("\n" + "="*30)
    print("=== VPN EC2 AWS ===")
    print("="*30)
    print("\nOpções:")
    print("1 - Ligar EC2 VPN STRONGSWAN")
    print("2 - Conectar via SSH")
    print("3 - Sair")

def process_choice(choice):
    """Processa a escolha do usuário."""
    if choice == "1" or choice == "start":
        start_instance()
    elif choice == "2" or choice == "get_ip":
        connect_via_ssh() # Chama a nova função de conexão
    elif choice == "3" or choice == "sair":
        print("\nEncerrando o script. Até mais!")
        return False
    else:
        print(f"Opção inválida: {choice}")
    return True

def main():
    # Modo CLI (com argumentos, executa e encerra)
    if len(sys.argv) >= 2:
        option = sys.argv[1].lower()
        process_choice(option)

    # Modo Interativo (sem argumentos, entra no loop)
    else:
        running = True
        while running:
            display_menu()
            try:
                choice = input("\n-> ").strip()
                running = process_choice(choice)
            except EOFError:
                break 
            except KeyboardInterrupt:
                print("\nSaindo...")
                break 

    # Pausa a execução APENAS no final.
    input("\nPressione Enter para sair...")

if __name__ == "__main__":
    main()
