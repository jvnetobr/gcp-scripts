import subprocess
import json
import pandas as pd

def verificar_api_habilitada(projeto_id, api):
    """
    Verifica se uma API está habilitada no projeto.
    """
    comando = [
        "gcloud", "services", "list",
        "--project", projeto_id,
        "--format=json"
    ]
    print(f"🛠️ Verificando se a API '{api}' está habilitada no projeto '{projeto_id}'...")
    resultado = subprocess.run(comando, capture_output=True, text=True)
    try:
        apis_habilitadas = json.loads(resultado.stdout)
        for servico in apis_habilitadas:
            if servico["config"]["name"] == api and servico["state"] == "ENABLED":
                return True
        return False
    except json.JSONDecodeError:
        print(f"⚠️ Erro ao verificar APIs no projeto: {projeto_id}")
        return False

def listar_vms_gcp(projeto_id):
    comando = [
        "gcloud", "compute", "instances", "list",
        "--project", projeto_id,
        "--format=json"
    ]
    print(f"🛠️ Executando comando para listar VMs no projeto '{projeto_id}': {' '.join(comando)}")
    resultado = subprocess.run(comando, capture_output=True, text=True)
    try:
        return json.loads(resultado.stdout)
    except json.JSONDecodeError:
        print(f"⚠️ Erro ao coletar VMs do projeto: {projeto_id}")
        return []

def listar_cloud_functions_gcp(projeto_id):
    comando = [
        "gcloud", "functions", "list",
        "--project", projeto_id,
        "--format=json"
    ]
    print(f"🛠️ Executando comando para listar Cloud Functions no projeto '{projeto_id}': {' '.join(comando)}")
    resultado = subprocess.run(comando, capture_output=True, text=True)
    try:
        return json.loads(resultado.stdout)
    except json.JSONDecodeError:
        print(f"⚠️ Erro ao coletar Cloud Functions do projeto: {projeto_id}")
        return []

def listar_cloud_sql_gcp(projeto_id):
    comando = [
        "gcloud", "sql", "instances", "list",
        "--project", projeto_id,
        "--format=json"
    ]
    print(f"🛠️ Executando comando para listar Cloud SQL no projeto '{projeto_id}': {' '.join(comando)}")
    resultado = subprocess.run(comando, capture_output=True, text=True)
    try:
        return json.loads(resultado.stdout)
    except json.JSONDecodeError:
        print(f"⚠️ Erro ao coletar Cloud SQL do projeto: {projeto_id}")
        return []

def coletar_dados_gcp(projetos):
    """
    Coleta os dados de IPs e recursos de VMs, Cloud Functions, e Cloud SQL.
    Se a API necessária não estiver habilitada, o recurso será ignorado.
    """
    dados = []
    for projeto_id in projetos:
        print(f"\n🔄 Iniciando coleta de dados do projeto: {projeto_id}")

        # Coletar VMs
        print(f"🔎 Coletando VMs no projeto: {projeto_id}")
        vms = listar_vms_gcp(projeto_id)
        for vm in vms:
            for interface in vm.get("networkInterfaces", []):
                acesso = interface.get("accessConfigs", [])
                if acesso:
                    ip_externo = acesso[0].get("natIP", "")
                    if ip_externo:
                        dados.append({
                            "cloud": "GCP",
                            "projeto_ou_grupo": projeto_id,
                            "nome_recurso": vm.get("name", ""),
                            "ip": ip_externo,
                            "dominio_customizado": ""
                        })
                        print(f"✅ VM encontrada: {vm.get('name')} com IP {ip_externo}")

        # Coletar Cloud Functions
        print(f"🔎 Coletando Cloud Functions no projeto: {projeto_id}")
        if verificar_api_habilitada(projeto_id, "cloudfunctions.googleapis.com"):
            functions = listar_cloud_functions_gcp(projeto_id)
            for function in functions:
                nome_func = function.get("name", "")
                endpoint = function.get("httpsTrigger", {}).get("url", "")
                if endpoint:
                    dados.append({
                        "cloud": "GCP",
                        "projeto_ou_grupo": projeto_id,
                        "nome_recurso": nome_func,
                        "ip": "",
                        "dominio_customizado": endpoint
                    })
                    print(f"✅ Cloud Function encontrada: {nome_func} com endpoint {endpoint}")
        else:
            print(f"❌ API 'cloudfunctions.googleapis.com' não habilitada no projeto '{projeto_id}'. Ignorando Cloud Functions.")

        # Coletar Cloud SQL
        print(f"🔎 Coletando Cloud SQL no projeto: {projeto_id}")
        if verificar_api_habilitada(projeto_id, "sqladmin.googleapis.com"):
            cloud_sql = listar_cloud_sql_gcp(projeto_id)
            for sql in cloud_sql:
                nome_sql = sql.get("name", "")
                ip_addresses = sql.get("ipAddresses", [])
                for ip_info in ip_addresses:
                    ip_address = ip_info.get("ipAddress", "")
                    tipo_ip = ip_info.get("type", "")  # Tipo: PRIMARY ou PRIVATE
                    if ip_address:
                        dados.append({
                            "cloud": "GCP",
                            "projeto_ou_grupo": projeto_id,
                            "nome_recurso": nome_sql,
                            "ip": ip_address,
                            "dominio_customizado": f"Tipo: {tipo_ip}"
                        })
                        print(f"✅ Cloud SQL encontrada: {nome_sql} com IP {ip_address} (Tipo: {tipo_ip})")
        else:
            print(f"❌ API 'sqladmin.googleapis.com' não habilitada no projeto '{projeto_id}'. Ignorando Cloud SQL.")

    return dados

def main():
    print("📥 Informe os IDs dos projetos GCP separados por vírgula:")
    entrada = input("Projetos: ")
    projetos = [p.strip() for p in entrada.split(",") if p.strip()]
    if not projetos:
        print("❌ Nenhum projeto informado.")
        return

    print("\n⏳ Iniciando coleta de dados para os projetos informados...")
    dados = coletar_dados_gcp(projetos)
    if dados:
        df = pd.DataFrame(dados)
        df.to_csv("ips_gcp_final.csv", index=False)
        print("\n✅ Arquivo 'ips_gcp_final.csv' gerado com sucesso!")
    else:
        print("\n❌ Nenhum dado coletado.")

if __name__ == "__main__":
    main()