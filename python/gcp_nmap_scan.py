import os
import subprocess
from googleapiclient import discovery
from google.auth import default

# Função para listar VMs e seus IPs
def list_vms(project_id):
    credentials, _ = default()
    service = discovery.build('compute', 'v1', credentials=credentials)
    request = service.instances().aggregatedList(project=project_id)
    
    vm_data = []
    while request is not None:
        response = request.execute()
        for zone, instances_scoped_list in response.get('items', {}).items():
            instances = instances_scoped_list.get('instances', [])
            for instance in instances:
                name = instance['name']
                network_interfaces = instance.get('networkInterfaces', [])
                for interface in network_interfaces:
                    access_configs = interface.get('accessConfigs', [])
                    for access_config in access_configs:
                        ip_address = access_config.get('natIP')
                        if ip_address:
                            vm_data.append({'name': name, 'ip': ip_address})
        request = service.instances().aggregatedList_next(previous_request=request, previous_response=response)
    return vm_data

# Função para executar Nmap e salvar resultados em um arquivo único
def run_nmap(ip, project_id, log_file):
    try:
        print(f"Scanning {ip}...")
        
        # Executar o comando Nmap e capturar a saída
        result = subprocess.run(['sudo', 'nmap', '-Pn', '-sS', '-p-', ip], capture_output=True, text=True)
        
        # Escrever os resultados no arquivo de log
        with open(log_file, "a") as file:
            file.write(f"\n--- Scanning VM: {ip} ---\n")
            file.write(result.stdout)  # Salva a saída no arquivo
            file.write("\n\n")  # Separação entre os escaneamentos

        print(f"Scan results for {ip} saved to {log_file}.")
    except Exception as e:
        print(f"Error scanning {ip}: {e}")

# Função principal
def main():
    project_id = input("Enter your GCP project ID: ").strip()
    
    # Criar o nome do arquivo de log baseado no nome do projeto
    log_file = f"{project_id}_nmap_scan_results.txt"
    
    print("Fetching VMs and their public IPs...")
    vms = list_vms(project_id)
    
    if not vms:
        print("No VMs with public IPs found in the project.")
        return
    
    print(f"Found {len(vms)} VM(s) with public IPs.")
    
    # Escanear as VMs e salvar os resultados no arquivo único
    for vm in vms:
        name, ip = vm['name'], vm['ip']
        print(f"\n--- Scanning VM: {name} (IP: {ip}) ---")
        run_nmap(ip, project_id, log_file)

    print(f"\nAll scan results are saved in: {log_file}")

if __name__ == "__main__":
    main()