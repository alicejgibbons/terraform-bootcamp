provider "azurerm" {
  version          = "1.7.0"
#  subscription_id = "REPLACE-WITH-YOUR-SUBSCRIPTION-ID"
#  client_id       = "REPLACE-WITH-YOUR-CLIENT-ID"
#  client_secret   = "REPLACE-WITH-YOUR-CLIENT-SECRET"
#  tenant_id       = "REPLACE-WITH-YOUR-TENANT-ID"
}

# ********************** Kubernetes Provider ******************************** #

provider "kubernetes" {
  version                = "1.1.0"
  host                   = "${azurerm_kubernetes_cluster.rg.kube_config.0.host}"
  username               = "${azurerm_kubernetes_cluster.rg.kube_config.0.username}"
  password               = "${azurerm_kubernetes_cluster.rg.kube_config.0.password}"
  client_certificate     = "${base64decode(azurerm_kubernetes_cluster.rg.kube_config.0.client_certificate)}"
  client_key             = "${base64decode(azurerm_kubernetes_cluster.rg.kube_config.0.client_key)}"
  cluster_ca_certificate = "${base64decode(azurerm_kubernetes_cluster.rg.kube_config.0.cluster_ca_certificate)}"
}

# randomize some things
resource "random_integer" "random_int" {
    min = 100
    max = 999
}

locals {
  dockercfg = {
    "${var.docker_server}" = {
      email    = "${var.docker_email}"
      username = "${var.docker_username}"
      password = "${var.docker_password}"
    }
  }
}

# create k8s secret for acr to use
resource "kubernetes_secret" "acr-secret" {
  "metadata" {
    name = "acr-secret"
  }

  data {
    ".dockercfg" = "${ jsonencode(local.dockercfg) }"
  }
  
  type = "kubernetes.io/dockercfg"
}

# deploy example container from acr 
resource "kubernetes_pod" "acr_example" {
  metadata {
    name = "aks-acr-example"
  }

  spec {
    image_pull_secrets = {
      name = "acr-secret"
    }
    
    container {
      name  = "azure-vote-front"
      image = "agtechsummit.azurecr.io/azure-vote-front:v1"
    }
  }
}

# ********************** Kubernetes Resource Group ************************** #
resource "azurerm_resource_group" "rg" {
  name     = "${var.resource_group}${random_integer.random_int.result}"
  location = "${var.location}"
}

# **************************** Kubernetes Cluster  ************************** #

resource "azurerm_kubernetes_cluster" "rg" {
  name                = "${var.cluster_name}"
  location            = "${azurerm_resource_group.rg.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  dns_prefix          = "${var.dns_prefix}${random_integer.random_int.result}"
  kubernetes_version  = "${var.kubernetes_version}"

  linux_profile { 
    admin_username = "${var.admin_username}"

    ssh_key {
      key_data = "${file("${var.ssh_public_data}")}"
    }
  }

  agent_pool_profile {
    name            = "default"
    count           = "${var.agent_count}"
    vm_size         = "${var.agent_vm_size}"
    os_type         = "Linux"
    os_disk_size_gb = 30
  }

  service_principal {
    client_id     = "${var.arm_client_id}"
    client_secret = "${var.arm_client_secret}"
  }

  tags {
    Environment = "Development"
  }
}
