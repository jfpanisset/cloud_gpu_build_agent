# Azure Pipelines Cloud GPU Build Agent on Google Cloud Platform

This small project demonstrates the basics of how to use [HashiCorp Terraform](https://terraform.io) to create a GPU-enabled VM on Google Cloud Platform (gcp) which can then be used to run build or test jobs from Azure Pipelines in the context of the [Academy Software Foundation](https://aswf.io) Continuous Integration framework.

## Creating a GCP Account

First you will need to [create a GCP account](https://console.cloud.google.com), by default Google provides some credits for experimentation. You will then need to go under "IAM & admin" and find the quota metric 'GPUs (all regions)' and change that from 0 to 1 to enable the creation of GPU-enabled VMs. This is not an automatic process, there may be a 12-24h wait before this is enabled (you will get email notification).

## Creating a Service Account Key

From the GCP console, you will need to create a Service Account Key:

- APIS & Services
- Credentials
- Create Service Account Key
- Select Default Service Account
- JSON key

This will create and download a service key, you should call it `USERNAME_gcp_credentials.json`, do NOT check this into a public repository as it would allow anyone to create resources in your infrastructure and incur costs.

## Install Terraform

On your local machine in this repository you should install Terraform, on Mac you can do this via [HomeBrew](https://brew.sh/)

```bash
brew install terraform
```
## Create a Personal Azure Token in Azure Pipelines

In Azure Pipelines you will need to create a Personal Access Token (PAT) to allow the agent to register itself as available for GPU builds and tests. Detailed instructions at [Self-hosted Linux agents](https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/v2-linux?view=azure-devops) but in summary:

- Click on your account icon at the top right of the Azure DevOps console
- Security
- Personal access tokens
- New Token

Once the token is generated save it somewhere safe, you will need it when installing the agent on the build VM.

## Create a Agent Pool in Azure Pipelines

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


## Building the VM with Terraform

The following commands should then create a VM with a K80 GPU on GCP:

```shell
terraform init
terraform plan
terraform apply -var 'your_username=YOURUSERNAME' -var 'your_credentials=YOURCREDENTIALSFILE.json'
```

The next step will be to automate the configuration of that VM, but for now you can ssh into it with:

```bash
ssh YOURNAME@`terraform output ip`
```

To install the NVIDIA driver:

```
sudo apt update
sudo apt install -y gcc make
wget http://us.download.nvidia.com/tesla/418.67/NVIDIA-Linux-x86_64-418.67.run
chmod +x NVIDIA-Linux-x86_64-418.67.run
sudo ./NVIDIA-Linux-x86_64-418.67.run
```

To install the Azure Pipelines agent (you will need your Personal Access Token for this step):

```
mkdir myagent && cd myagent
cd myagent
wget https://vstsagentpackage.azureedge.net/agent/2.153.2/vsts-agent-linux-x64-2.153.2.tar.gz
tar xvf vsts-agent-linux-x64-2.153.2.tar.gz
./config.sh
Enter server URL > https://dev.azure.com/panisset0719
Enter authentication type (press enter for PAT) >
Enter personal access token > ****************************************************
Enter agent pool (press enter for default) > GPU Ubuntu 18.04
Enter agent name (press enter for aswf-gpu-build-2d993f3838d2431e) >
```

At this point if you go back to your Azure Pipelines project and look at your custom agent pool (`GPU Ubuntu 18.04` in my test case), you should see your custom agent available, and if you run a build that calls for this agent pool, perhaps with a NVIDIA-specific shell command such as:

```shell
nvidia-smi
```

it should execute correctly.




