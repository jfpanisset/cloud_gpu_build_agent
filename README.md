# Azure Pipelines Cloud GPU Build Agent

This small project demonstrates the basics of how to use [HashiCorp Terraform](https://terraform.io) to create a GPU-enabled VM on Google Cloud Platform (gcp) or Microsoft Azure which can then be used to run build or test jobs from Azure Pipelines in the context of the [Academy Software Foundation](https://aswf.io) Continuous Integration framework.

## Azure Pipelines Setup

### Create a Personal Acess Token in Azure Pipelines

In Azure Pipelines you will need to create a Personal Access Token (PAT) to allow the agent to register itself as available for GPU builds and tests. Detailed instructions at [Self-hosted Linux agents](https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/v2-linux?view=azure-devops) but in summary:

- Click on your account icon at the top right of the Azure DevOps console
- Security
- Personal access tokens
- New Token

Once the token is generated save it somewhere safe, you will need it when installing the agent on the build VM.

### Create a Agent Pool in Azure Pipelines

In Azure Pipelines go to:

- Project Settings (bottom left of the screen for a project)
- Pipelines
- Agent Pools
- Add pool

and create a new pool for your GPU builder, I called mine "GPU Ubuntu 18.04". In your `azure_pipelines.yml` pipeline definition file for your project you will want to specify something like:

```yaml
jobs:
- job: Linux
  pool:
    name: 'GPU Ubuntu 18.04'
```

to force a job to run on your custom build agent from your custom agent pool instead of using the pre-defined agent pools provided by Azure Pipelines.

## Local Setup

### Install Terraform

On your local machine in this repository you should install Terraform, on Mac you can do this via [HomeBrew](https://brew.sh/)

```bash
brew install terraform
```
## Cloud Provider Setup

### Google Cloud Platform Setup

#### Creating a GCP Account

First you will need to [create a GCP account](https://console.cloud.google.com), by default Google provides some credits for experimentation. You will then need to go under "IAM & admin" and find the quota metric 'GPUs (all regions)' and change that from 0 to 1 to enable the creation of GPU-enabled VMs. This is not an automatic process, there may be a 12-24h wait before this is enabled (you will get email notification).

#### Creating a Service Account Key

From the GCP console, you will need to create a Service Account Key:

- APIS & Services
- Credentials
- Create Service Account Key
- Select Default Service Account
- JSON key

This will create and download a service key, you should call it `USERNAME_gcp_credentials.json`, do NOT check this into a public repository as it would allow anyone to create resources in your infrastructure and incur costs.

#### Building the VM with Terraform

The following commands should then create a VM with a K80 GPU on GCP:

```bash
cd gcp
terraform init
terraform apply -var 'your_credentials=YOURCREDENTIALSFILE.json' \
    -var 'azure_pipelines_token=YOUR_AZURE_PIPELINES_PAT_TOKEN' \
    -var 'azure_pipelines_organization=YOUR_AZURE_PIPELINES_ORGANIZATION'
```

This will copy your public SSH key from your `~/.ssh/id_rsa.pub` file to the VM to enable passwordless `ssh` access:

```bash
ssh testadmin@`terraform output public_ip_address`
```

(you can change the name of the admin user in `variables.tf`).

### Microsoft Azure Setup

This article on how to [Create a complete Linux virtual machine infrastructure in Azure with Terraform](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/terraform-create-complete-vm) is a good starting point for the Terraform code required to build a Linux VM on Azure to use as a GPU enabled Azure Pipelines build agent.

#### Installing the Azure CLI and Authentication

The Azure CLI will be used to set up authentication against your Azure account. As per [Install the Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest) on macOS you can install it using [HomeBrew](https://brew.sh/):

```bash
brew update && brew install azure-cli
```

Next you will want to [Create a Service Principal using the CLI](https://www.terraform.io/docs/providers/azurerm/auth/service_principal_client_secret.html) (assuming you have a single subscription for the sake of simplicity). The initial login into Azure from the CLI will open a web browser to allow you to enter credentials:

```bash
az login
az ad sp create-for-rbac --role="Contributor" --scopes="/subscriptions/SUBSCRIPTION_ID"
```

where `SUBSCRIPTION_ID` will be in the JSON output from `az login`. From the JSON output of `az ad sp create-for-rbac` you should record:

- `id` will be used as the `SUBSCRIPTION_ID`
- `appId` will be used as the `CLIENT_ID`
- `password` will be used as the `CLIENT_SECRET`
- `tenant` will be used as the `TENANT_ID`

You should then be able to login from the command line (without going through a browser) with:

```bash
az login --service-principal -u CLIENT_ID -p CLIENT_SECRET --tenant TENANT_ID
```

but from this point on you shouldn't need to use the CLI anymore, so you can close your session:

```bash
az logout
```

#### Building the Azure VM with Terraform

Set the following environment variables with the values gathered from the previous section in the shell you will be using `terraform` from:

```bash
export ARM_CLIENT_ID="00000000-0000-0000-0000-000000000000"
export ARM_CLIENT_SECRET="00000000-0000-0000-0000-000000000000"
export ARM_SUBSCRIPTION_ID="00000000-0000-0000-0000-000000000000"
export ARM_TENANT_ID="00000000-0000-0000-0000-000000000000"
```

The Terraform Azure Resource Manager will let you create a virtual machine using the 

```bash
cd azure
terraform init
terraform apply -refresh=true \
    -var 'azure_pipelines_token=YOUR_AZURE_PIPELINES_PAT_TOKEN' \
    -var 'azure_pipelines_organization=YOUR_AZURE_PIPELINES_ORGANIZATION'
```

This will copy your public SSH key from your `~/.ssh/id_rsa.pub` file to the VM to enable passwordless `ssh` access:


```bash
ssh testadmin@`terraform output public_ip_address`
```

(you can change the name of the admin user in `variables.tf`).

### Terraform and Ansible for Provisioning

 [Ansible](https://www.ansible.com/) is used to provision the VM, although there is no official Ansible provisioner for Terraform this can be done using the `remote-exec` and `local-exec` provisioners as per [How to use Ansible with Terraform](https://alex.dzyoba.com/blog/terraform-ansible/.)

The `provision.yml` playbook will do the following:

- install gcc and make
- download and install the NVIDIA driver
- download and install the Azure Pipelines agent
- install the Azure Pipelines agent as a system service and start it

In more details:

```bash
sudo apt update
sudo apt install -y gcc make
wget http://us.download.nvidia.com/tesla/418.67/NVIDIA-Linux-x86_64-418.67.run
chmod +x NVIDIA-Linux-x86_64-418.67.run
sudo ./NVIDIA-Linux-x86_64-418.67.run -s
```

The Azure Pipelines agent configuration will use your PAT (Personal Access Token) and Azure Pipelines Organization:

```bash
mkdir myagent && cd myagent
cd myagent
wget https://vstsagentpackage.azureedge.net/agent/2.153.2/vsts-agent-linux-x64-2.153.2.tar.gz
tar xvf vsts-agent-linux-x64-2.153.2.tar.gz
./config.sh
Enter server URL > https://dev.azure.com/YOUR_AZURE_PIPELINE_ORG
Enter authentication type (press enter for PAT) >
Enter personal access token > ****************************************************
Enter agent pool (press enter for default) > GPU Ubuntu 18.04
Enter agent name (press enter for aswf-gpu-build-2d993f3838d2431e) >
```

And to install the agent as a system service and start it:

```bash
sudo ./svc.sh install
sudo ./svc.sh start
```

At this point if you go back to your Azure Pipelines project and look at your custom agent pool (`GPU Ubuntu 18.04` in my test case), you should see your custom agent available, and if you run a build that calls for this agent pool, perhaps with a NVIDIA-specific shell command such as:

```bash
nvidia-smi
```

it should execute correctly.

### Destroying your Cloud Infrastructure

As long as your VM is running, it is generating costs, so don't forget to destroy it when you are done:

```bash
terraform destroy
```

This functionality does not seem to always work, so you may need to destroy your resources from the GCP or Azure web console.





