# Dify Azure Deployment with Bicep

This README provides instructions on how to use the Bicep templates to deploy the Dify application on Azure.

## Prerequisites

1. Azure CLI installed and logged in
2. Bicep CLI installed
3. Azure subscription

## Files Structure

- `main.bicep`: The main Bicep file that orchestrates the deployment
- `modules/`: Directory containing modular Bicep files
  - `vnet.bicep`: Virtual Network configuration
  - `postgresql.bicep`: Azure Database for PostgreSQL configuration
  - `redis.bicep`: Azure Cache for Redis configuration
  - `storage.bicep`: Azure Storage Account configuration
  - `aca.bicep`: Azure Container Apps configuration

## Deployment Steps

1. Clone this repository to your local machine.

2. Navigate to the `bicep` directory.

3. Review and modify the parameters in `main.bicep` if needed. You may want to change default values or add new parameters.

4. Create a parameters file named `main.parameters.json` with the following content (replace values as needed):

   ```json
   {
     "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
     "contentVersion": "1.0.0.0",
     "parameters": {
       "location": {
         "value": "japaneast"
       },
       "postgresAdminPassword": {
         "value": "YourStrongPasswordHere"
       },
       "acaCertPassword": {
         "value": "YourCertificatePasswordHere"
       },
       "acaCertContent": {
         "value": "YourBase64EncodedCertificateContent"
       }
     }
   }
   ```

5. To get the base64-encoded content of your certificate, use the following command:

   ```
   certutil -encode .\certs\difycert.pfx temp.b64 && findstr /v /c:- temp.b64 > cert.b64 && del temp.b64
   ```

   Then, copy the content of `cert.b64` into the `acaCertContent` parameter in your `main.parameters.json` file.

6. Deploy the Bicep template using Azure CLI:

   ```bash
   az deployment sub create --location japaneast --template-file main.bicep --parameters main.parameters.json
   ```

   This command deploys the resources at the subscription level.

7. Monitor the deployment progress in the Azure portal or through the Azure CLI.

## Post-Deployment

After successful deployment:

1. Configure your domain's DNS to point to the public IP address of the nginx Container App.
2. Verify that all Container Apps are running correctly.
3. Access the Dify application through the configured domain.

## Customization

You can customize the deployment by modifying the Bicep files:

- Adjust resource SKUs in respective module files.
- Modify network configurations in `vnet.bicep`.
- Add or remove environment variables in `aca.bicep`.

## Troubleshooting

- Check Azure Container Apps logs for any application-specific issues.
- Verify network connectivity between resources if experiencing connection problems.
- Ensure all required environment variables are correctly set in the Container Apps.

## Security Note

- The `main.parameters.json` file contains sensitive information. Ensure it's not committed to version control.
- Consider using Azure Key Vault for storing and retrieving sensitive parameters during deployment.

## Support

For issues related to the Bicep templates, please open an issue in this repository. For Dify-specific problems, refer to the [Dify GitHub repository](https://github.com/langgenius/dify).

## Estimated Monthly Costs

Here's a rough estimate of the monthly costs for running this solution in Azure. Please note that these are approximate figures and actual costs may vary based on usage, region, and current pricing:

1. Azure Container Apps Environment: ~$75/month
   - Includes consumption-based pricing for container instances

2. Azure Database for PostgreSQL (Flexible Server, Standard_B1ms): ~$50/month

3. Azure Cache for Redis (Standard C0): ~$40/month

4. Azure Storage Account (Standard LRS): ~$20/month
   - Includes blob storage for file uploads and Azure File shares

5. Virtual Network and associated resources: ~$5/month

Total estimated cost: ~$190/month

Please note that this is a basic estimate and doesn't include potential costs for data transfer, additional storage, or scaling resources based on usage. It's recommended to use the Azure Pricing Calculator for a more accurate estimate based on your specific requirements and region.
