# Cloud Build Private Worker Pool

Reference implementation of Private Worker Pools with no external IP.

Configured to chat to Google API's over private.googleapis.com, and Docker Hub with L7 Firewall rules.

## Instructions

1. Edit `000-locals.tf` as appropriate
2. Apply the Terraform
3. Run the sample Cloud Build YAML:

Set vars
```
PROJECT_ID=appmod-golden-demo-dev

gcloud beta builds submit \
 --no-source --substitutions=_ARTIFACT_REGISTRY_PATH_=us-central1-docker.pkg.dev/$PROJECT_ID/test-docker-gcb,_SERVICE_ACCOUNT_EMAIL_="projects/$PROJECT_ID/serviceAccounts/gcb-worker-service-account@$PROJECT_ID.iam.gserviceaccount.com" \
 --project=$PROJECT_ID \
 --worker-pool=projects/$PROJECT_ID/locations/us-central1/workerPools/private-pool \
 --region=us-central1 \
 --config=resources/cloudbuild.yaml
```
