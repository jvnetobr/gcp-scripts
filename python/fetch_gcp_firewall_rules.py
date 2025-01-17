import subprocess

def run_command_and_save_output(command, output_file):
    try:
        print(f"Running command: {' '.join(command)}")
        result = subprocess.run(command, capture_output=True, text=True, check=True)
        
        with open(output_file, "w") as file:
            file.write(result.stdout)
        
        print(f"Output saved to {output_file}")
    except subprocess.CalledProcessError as e:
        print(f"Error executing command: {e}")
        with open(output_file, "w") as file:
            file.write(f"Error executing command: {e}\n")
            file.write(e.stderr if e.stderr else "No additional error details available.\n")

def main():
    # Solicitar o nome do projeto ao usuário
    project_id = input("Enter the GCP project ID: ").strip()
    
    if not project_id:
        print("Project ID cannot be empty. Exiting...")
        return
    
    gcp_command = [
        "gcloud", "compute", "firewall-rules", "list",
        f"--project={project_id}",
        "--filter=direction=INGRESS",
        "--format=table(name,sourceRanges,allowed)"
    ]
    
    # Nome do arquivo de saída
    output_file = f"{project_id}_firewall_rules.txt"
    
    print(f"\nFetching firewall rules for project: {project_id}")
    run_command_and_save_output(gcp_command, output_file)

if __name__ == "__main__":
    main()