# Azure Pipelines Cloud GPU Build Agent

This small project demonstrates the basics of how to use [HashiCorp Terraform](https://terraform.io) to create a GPU-enabled VM on Google Cloud Platform (gcp), Microsoft Azure or Amazone AWS which can then be used to run build or test jobs from Azure Pipelines in the context of the [Academy Software Foundation](https://aswf.io) Continuous Integration framework. The Terraform code requires version 0.12 or newer of Terraform due to [changes in the variable interpolation syntax](https://www.terraform.io/upgrade-guides/0-12.html#first-class-expressions).

To run hardware accelerated OpenGL on a NVIDIA GPU in a virtual machine, you need a [NVIDIA GRID vGPU license](https://www.nvidia.com/en-us/data-center/virtual-pc-apps/) which can be provided by the Cloud Service Provider. The base K80 GPU typically available on public clouds does not support GRID and will not support OpenGL, only CUDA. A GPU which supports GRID licensing is required, Azure offers the M60 on its NV series of VMs, Amazon on its `g3.xlarge` instances, and GCP offers the P4. Instructions on how to obtain and install a cloud provider specific pre-licensed NVIDIA driver are available at:

- Azure: [Install NVIDIA GPU drivers on N-Series VMs running Linux](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/n-series-driver-setup)
- AWS: [Installing the NVIDIA Driver on Linux Instances](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/install-nvidia-driver.html)
- GCP: [Installing GRID drivers for virtual workstations](https://cloud.google.com/compute/docs/gpus/add-gpus#installing_grid_drivers_for_virtual_workstations)


## Azure Pipelines Setup

### Create a Personal Access Token in Azure Pipelines

In Azure Pipelines you will need to create a Personal Access Token (PAT) to allow the agent to register itself as available for GPU builds and tests. Detailed instructions at [Self-hosted Linux agents](https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/v2-linux?view=azure-devops) but in summary:

- Click on your account icon at the top right of the Azure DevOps console
- Security
- Personal access tokens
- New Token

Once the token is generated save it somewhere safe, you will need it when installing the agent on the build VM.

### Create an Agent Pool in Azure Pipelines

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

to force a job to run on your custom build agent from your custom agent pool instead of using the pre-defined (Microsoft hosted) agent pools provided by Azure Pipelines. It is also possible to create an agent pool at the organization level, when creating the agent pool at the project level you will have the option to link an existing agent pool.

Unfortunately the `az pipelines pool` currently does not support creating agent pools, so this step cannot be automated without resorting to using the Azure DevOps REST API.

## Local Setup

### Setting Environment Variables

In a CI environment it is generally preferable to pass "secrets" as environment variables: command line parameters typically end up recorded in log files, and you definitely don't want to store secrets in files that will end up in your public code repository. If this workflow is automated, you can store these secrets using using the secrets storage functionality of the CI system. If running this manually, in the shell from where you will be calling Terraform, the following environment variables are used to pass the Azure DevOps project and Personal Access Token to the Ansible provisioning script:

```bash
export AZURE_DEVOPS_ORGANIZATION=my_azdevops_org
export AZURE_DEVOPS_PAT_TOKEN=theverylongazdevopspatstring
```

If you are running on macOS, you will probably need to set the following to work around an [issue with Ansible and Python in recent macOS versions](#terraform-and-ansible-for-provisioning):

```bash
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
```

Finally, you will need to set environment variables specific to the cloud service you are using (see additional details in the sections on each cloud provider). A Terraform variable called `foo` will have its value set to `bar` by an environment variable called `TF_VAR_foo` with value `bar`, you could also use the command line option `-var foo=bar` to `terraform apply`.

- Google GCP
        FIXME
- Azure
        export ARM_CLIENT_ID="00000000-0000-0000-0000-000000000000"
        export ARM_CLIENT_SECRET="00000000-0000-0000-0000-000000000000"
        export ARM_SUBSCRIPTION_ID="00000000-0000-0000-0000-000000000000"
        export ARM_TENANT_ID="00000000-0000-0000-0000-000000000000"
- Amazon AWS
        export TF_VAR_aws_access_key_id=XXXXXX
        export TF_VAR_aws_secret_access_key=XXXXXX

### Install Terraform

On your local machine in this repository you should install Terraform, on Mac you can do this via [HomeBrew](https://brew.sh/)

```bash
brew install terraform
```
## Cloud Provider Setup

### Google Cloud Platform (GCP) Setup

This tutorial on [Getting Started with Terraform on Google Cloud Platform](https://cloud.google.com/community/tutorials/getting-started-on-gcp-with-terraform) is a good starting point to create the GCP resources we need with Terraform, as well as [Managing GCP Projects with Terraform](https://cloud.google.com/community/tutorials/managing-gcp-projects-with-terraform).

#### Creating a GCP Account

First you will need to [create a GCP account](https://console.cloud.google.com), by default Google provides some credits for experimentation.

#### Installing the GCP Command CLI and Authentication

The GCP CLI will be used to set up authentication against your GCP account. As per [Homebrew Google Cloud SDK](https://formulae.brew.sh/cask/google-cloud-sdk) on macOS you can install it using [HomeBrew](https://brew.sh/):

```bash
brew update && brew cask install google-cloud-sdk
```

Next you need to [authorize access for the Cloud SDK tools](https://cloud.google.com/sdk/docs/authorizing). We will be using the "Authorizing with a service account" method:

* [Initialize the Cloud SDK](https://cloud.google.com/sdk/docs/initializing): a browser window will allow you to login to your Google account and authorize the Google Cloud SDK. You will be prompted to enter a project name to create, which will set the name of the current project (note that GCP does not allow you to reuse the name of a previously deleted project):
```bash
    gcloud init
```
* [Go to the Service Accounts Page](https://console.cloud.google.com/iam-admin/serviceaccounts), select the project you just created from popup list at top of screen, and create a service account for that project (the name doesn't matter too much, but you can use the project name as the service account name to keep things smple). Under "Role" select "Project -> Owner" to give full permissions to the service account.
* Under "Key Type' select JSON format and click "Create". This will create the service account and download a service key, you should rename it `USERNAME_gcp_credentials.json`, do NOT check this into a public repository as it would allow anyone to create resources in your infrastructure and incur costs.
* Under "Billing" you need to enable billing for your project using the billing account you initially created when you created your GCP account.
* Under "IAM & admin" select "Quotas", find the quota metric "GPUs (all regions)" and change that from 0 to 1 to enable the creation of GPU-enabled VMs. This is not an automatic process, there may be a 12-24h wait before this is enabled (you will get email notification).

The `gcloud` CLI can then be used to enable the required APIs for this project to allow Terraform to control it using the service account. Note that some APIs can take a surprising amount of time to initialize.

```bash
gcloud auth activate-service-account --key-file=USERNAME_gcp_credentials.json
gcloud config set project PROJECTNAME
gcloud services enable "cloudresourcemanager.googleapis.com"
gcloud services enable "serviceusage.googleapis.com"
gcloud services enable "cloudbilling.googleapis.com"
```

Additional APIs will be enabled by Terraform. Terraform should now be able to create and manipulate resources in your GCP project.

#### Building the VM with Terraform

The following commands should then create a VM with a P4 GPU on GCP:

```bash
cd gcp
terraform init
terraform apply -var 'prefix=PROJECTNAME' \
    -var 'your_credentials=USERNAME_gcp_credentials.json'
```

If you have been using the same directory for a while, you may want to use instead:

```bash
terraform init -upgrade
terraform get -update
```

to download updates to providers and modules.

This will copy your public SSH key from your `~/.ssh/id_rsa.pub` file to the VM to enable passwordless `ssh` access:

```bash
ssh testadmin@`terraform output public_ip_address`
```

You can change the name of the admin user in `variables.tf`. On AWS the administrative account is [based on the AMI you are using](https://alestic.com/2014/01/ec2-ssh-username/), for instance for Ubuntu it is `ubuntu`, there does not seem to be a simple way to change that at instance creation time.

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

The Terraform Azure Resource Manager will let you create a virtual machine using the following commands:

```bash
cd azure
terraform init
terraform apply
```

If you have been using the same directory for a while, you may want to use instead:

```bash
terraform init -upgrade
terraform get -update
```

to download updates to providers and modules.

This will copy your public SSH key from your `~/.ssh/id_rsa.pub` file to the VM to enable passwordless `ssh` access:


```bash
ssh testadmin@`terraform output public_ip_address`
```

(you can change the name of the admin user in `variables.tf`).

### Amazon Web Services (AWS) Setup

To create a suitable AWS EC2 instance (VM), we first need to configure programatic access to AWS, and we can leverage the [aws command line interface](https://aws.amazon.com/cli/) as much as possible.

On macOS, we use the [Homebrew awscli formula](https://formulae.brew.sh/formula/awscli) to install the package:

```bash
brew install awscli
```

Assuming you have already created an AWS account and are logged in to the AWS console, the [Your Security Credentials](https://console.aws.amazon.com/iam/home?#/security_credentials) page in the AWS console will let you create an API Access Key to be used by Terraform. This is a shortcut for the sake of illustration: AWS strongly suggests creating a dedicated user under Identity and Access Management (IAM) with a limited set of permissions. Click on "Create New Key" under the "Access keys (access key ID and secret access key)" tab, and then "Download Key File" which will download a file called `rootkey.csv`. Copy this file to the `aws` folder of your copy of this repo, do NOT check it in to any public repository.

As per the Terraform [Getting Started - AWS tutorial](https://learn.hashicorp.com/terraform/getting-started/build):

```bash
$ aws configure
AWS Access Key ID [None]: YOUR_ACCESS_KEY_ID
AWS Secret Access Key [None]: YOUR_SECRET_ACCESS_KEY
Default region name [None]: westus2
Default output format [None]:
```

This will store a copy of the credentials in your `~/.aws/credentials` file under the `default` profile. Other approaches are possible as well, see [Authenticating to AWS with the Credentials File](https://blog.gruntwork.io/authenticating-to-aws-with-the-credentials-file-d16c0fbcbf9e) and [Authenticating to AWS with Environment Variables](https://blog.gruntwork.io/authenticating-to-aws-with-environment-variables-e793d6f6d02e). Set the following environment variables to pass the credentials to Terraform:

```bash
export TF_VAR_aws_access_key_id=XXXXXX
export TF_VAR_aws_secret_access_key=XXXXXX
```

You should then be able to run:

```bash
cd aws
terraform init
terraform apply -var 'prefix=PROJECTNAME'
```

The first time you try to run this Terraform code, you may get the following error:

```
Error launching source instance: PendingVerification: Your request for accessing resources in this region is being validated, and you will not be able to launch additional resources in this region until the validation is complete. We will notify you by email once your request has been validated. While normally resolved within minutes, please allow up to 4 hours for this process to complete. If the issue still persists, please let us know by writing to aws-verification@amazon.com for further assistance.
```

This may be due to a first time use of a billable resource, and the need to verify the billing information on the AWS account. This should get approved automatically if the AWS account has a valid payment method set up.

You may also get the following error:

```
Error: Error launching source instance: VcpuLimitExceeded: You have requested more vCPU capacity than your current vCPU limit of 0 allows for the instance bucket that the specified instance type belongs to. Please visit http://aws.amazon.com/contact-us/ec2-request to request an adjustment to this limit.
```

This requires manual intervention in the AWS console to increase the vCPU limit based on the EC2 instance you are requesting. The following URL should take you directly to the AWS Console to [request a vCPU quota increase for running on-demand g3s-series instances in the us-west-2 region](https://us-west-2.console.aws.amazon.com/servicequotas/home?region=us-west-2#!/services/ec2/quotas/L-9675FDCD). The limit increases are per instance type, make sure to request the increase for the correct ype.

### Terraform and Ansible for Provisioning

 [Ansible](https://www.ansible.com/) is used to provision the VM, although there is no official Ansible provisioner for Terraform this can be done using the `remote-exec` and `local-exec` provisioners as per [How to use Ansible with Terraform](https://alex.dzyoba.com/blog/terraform-ansible/.)

 If you are running Ansible on macOS and get an error similar to:

 ```bash
 objc[2823]: +[__NSPlaceholderDate initialize] may have been in progress in another thread when fork() was called.
objc[2823]: +[__NSPlaceholderDate initialize] may have been in progress in another thread when fork() was called. We cannot safely call it or ignore it in the fork() child process. Crashing instead. Set a breakpoint on objc_initializeAfterForkError to debug.
```

you may be running into a [previously reported issue](https://github.com/ansible/ansible/issues/32499): a security update introduced in macOS High Sierra tends to break Python apps which call `fork()`, a potential workaround is to set the environment variable:

```bash
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
```

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

## NVIDIA Drivers and Containers

Running GPU accelerated containers inside of a Docker container is still in flux, but the situation is rapidly improving. As per the [NVIDIA Container Toolkit project](https://github.com/NVIDIA/nvidia-docker), [Docker 19.03 now includes native support for NVIDIA GPUs](https://github.com/moby/moby/pull/38828). The Ansible recipe in this project installs the `nvidia-container-toolkit` package sets up Docker to allow containers access to the NVIDIA driver and GPU running on the host when using the `--gpus` option, for instance:

```bash
#### Test nvidia-smi with the latest official CUDA image
$ docker run --gpus all nvidia/cuda:9.0-base nvidia-smi
```

should run the `nvidia-smi` utility inside a GPU-enabled container and print information about the GPU on the host.

For CUDA applications it is no longer necessary to install the CUDA toolkit on the host, it only needs to be present inside the container.
