from google.cloud import compute_v1

def create_firewall_rule(project_id, network_name, firewall_rule_name, allowed_ports, source_ranges, direction='INGRESS', priority=1000):
    firewall_client = compute_v1.FirewallsClient()

    # Construindo a regra de firewall
    firewall_rule = compute_v1.Firewall()
    firewall_rule.name = firewall_rule_name
    firewall_rule.network = f'projects/{project_id}/global/networks/{network_name}'
    firewall_rule.direction = direction
    firewall_rule.priority = priority
    firewall_rule.allowed = [
        compute_v1.Allowed(
            IP_protocol='tcp',
            ports=allowed_ports
        )
    ]
    firewall_rule.source_ranges = source_ranges

    # Aplicando a regra de firewall
    operation = firewall_client.insert(project=project_id, firewall_resource=firewall_rule)

    # Esperando a operação ser concluída
    wait_for_operation(project_id, operation.name)
    print(f"Regra de firewall '{firewall_rule_name}' aplicada com sucesso à VPC '{network_name}'.")

def wait_for_operation(project_id, operation_name):
    operations_client = compute_v1.GlobalOperationsClient()
    while True:
        operation = operations_client.get(project=project_id, operation=operation_name)
        if operation.status == compute_v1.Operation.Status.DONE:
            if operation.error:
                raise Exception(f"Erro ao aplicar a regra de firewall: {operation.error}")
            return
        print("Aguardando a conclusão da operação...")

if __name__ == "__main__":
    project_id = input("Digite o ID do projeto: ")
    network_name = input("Digite o nome da VPC: ")
    firewall_rule_name = input("Digite o nome da regra de firewall: ")
    allowed_ports = input("Digite as portas permitidas (separadas por vírgula): ").split(',')
    source_ranges = input("Digite os intervalos de origem (separados por vírgula): ").split(',')

    create_firewall_rule(project_id, network_name, firewall_rule_name, allowed_ports, source_ranges)