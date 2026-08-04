import os
import sys
import requests
from google.auth.transport.requests import Request
from google.oauth2 import service_account

# Reconfigure stdout to avoid encoding errors
sys.stdout.reconfigure(encoding='utf-8')

backend_dir = os.path.dirname(os.path.abspath(__file__))
project_dir = os.path.dirname(backend_dir)
key_path = os.path.join(backend_dir, "firebase-service-account.json")
rules_path = os.path.join(project_dir, "firestore.rules")

if not os.path.exists(key_path):
    print(f"Error: Credentials not found at {key_path}")
    sys.exit(1)

if not os.path.exists(rules_path):
    print(f"Error: firestore.rules not found at {rules_path}")
    sys.exit(1)

# Authenticate with Google API
credentials = service_account.Credentials.from_service_account_file(
    key_path,
    scopes=["https://www.googleapis.com/auth/cloud-platform"]
)

# Fetch oauth access token
print("Refreshing Google credentials...")
credentials.refresh(Request())
token = credentials.token
project_id = credentials.project_id

# Read rules content
with open(rules_path, "r", encoding="utf-8") as f:
    rules_content = f.read()

# 1. Create a new ruleset
ruleset_url = f"https://firebaserules.googleapis.com/v1/projects/{project_id}/rulesets"
headers = {
    "Authorization": f"Bearer {token}",
    "Content-Type": "application/json"
}
ruleset_body = {
    "source": {
        "files": [
            {
                "content": rules_content,
                "name": "firestore.rules"
            }
        ]
    }
}

print(f"Creating new ruleset for project: {project_id}...")
response = requests.post(ruleset_url, json=ruleset_body, headers=headers)
if response.status_code != 200:
    print(f"Failed to create ruleset: {response.status_code}\n{response.text}")
    sys.exit(1)

ruleset_data = response.json()
ruleset_name = ruleset_data["name"]
print(f"Successfully created ruleset: {ruleset_name}")

# 2. Update release to point to the new ruleset
release_url = f"https://firebaserules.googleapis.com/v1/projects/{project_id}/releases/cloud.firestore"
release_body = {
    "release": {
        "name": f"projects/{project_id}/releases/cloud.firestore",
        "rulesetName": ruleset_name
    }
}

print("Updating cloud.firestore release to point to the new ruleset...")
release_response = requests.patch(release_url, json=release_body, headers=headers)
if release_response.status_code != 200:
    print(f"Failed to update rules release: {release_response.status_code}\n{release_response.text}")
    sys.exit(1)

print("Firestore Security Rules successfully deployed to the cloud!")
