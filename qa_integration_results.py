import os
import csv
import requests

def get_user_details(login_name, token):
    headers = {
        "Authorization": f"token {token}",
        "Accept": "application/vnd.github.v3+json"
    }
    url = f"https://api.github.com/users/{login_name}"
    response = requests.get(url, headers=headers)
    if response.status_code == 200:
        return response.json()["name"]
    else:
        print("Failed to fetch user details")
        return None

def get_workflow_runs(owner, repo, job_name, token):
    headers = {
        "Authorization": f"token {token}",
        "Accept": "application/vnd.github.v3+json"
    }
    url = f"https://api.github.com/repos/{owner}/{repo}/actions/runs"
    params = {
        "event": "workflow_dispatch",
        "workflow_id": job_name
    }
    response = requests.get(url, headers=headers, params=params)
    if response.status_code == 200:
        return response.json()["workflow_runs"]
    else:
        print("Failed to fetch workflow runs")
        return None

# Example usage:
owner = "Percona-Lab"
repo = "qa-integration"
job_name = os.environ.get("JOB_NAME")  # Get job_name from environment variable
token = os.environ.get("PK_GITHUB_TOKEN")  # Get token from environment variable

workflow_runs = get_workflow_runs(owner, repo, job_name, token)
if workflow_runs:
    os.makedirs("results", exist_ok=True)
    csv_filename = f'results/workflow_runs_{job_name}.csv'
    with open(csv_filename, 'w', newline='') as csvfile:
        fieldnames = ['Run ID', 'Triggered By', 'Created At', 'Status']
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        writer.writeheader()
        for run in workflow_runs:
            triggered_by = run["triggering_actor"]["login"]
            user_name = get_user_details(triggered_by, token)
            writer.writerow({
                'Run ID': run["id"],
                'Triggered By': user_name if user_name else triggered_by,
                'Created At': run["created_at"],
                'Status': run["conclusion"]
            })

    print(f"Data exported to {csv_filename} file successfully.")
