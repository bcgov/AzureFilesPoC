# secrets.tfvars for dev environment
# NEVER commit this file to version control!
# Used for local development or CI/CD if not using OIDC.

#application name and service principal name
#=============================================
#Application/ServicePrincipalName: ag-pssg-azure-files-poc-ServicePrincipal
#=============================================
#application client ID=ace4c5df-cd88-44cb-90d5-77dac445f2ee
#application object ID=bdd44294-0bfc-434a-9340-4c311c316966
#service principal object ID = e72f42f8-d9a1-4181-a0b9-5c8644a28aee
#service principlal application ID = ace4c5df-cd88-44cb-90d5-77dac445f2ee
#azure_tenant_id = 6fdb5200-3d0d-4a8a-b036-d3685e359adc

#SECRETS IN GITHUB ALSO
azure_client_id = "ace4c5df-cd88-44cb-90d5-77dac445f2ee" #ag-pssg-azure-files-poc-ServicePrincipal
#azure_client_id = "df5e984f-1b31-480a-a16f-8431dbb84bb8" #ag-pssg-azure-files-poc-ServicePrincipal

# azure_client_secret = "<not needed for OIDC/GitHub Actions>"
azure_tenant_id = "6fdb5200-3d0d-4a8a-b036-d3685e359adc"
azure_subscription_id = "d321bcbe-c5e8-4830-901c-dab5fab3a834"
