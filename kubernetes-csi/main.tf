terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = ">= 0.100.0"
    }
  }
}

provider "yandex" {
  # Токен или service_account_key_file, folder_id и cloud_id можно задать через переменные окружения
}

# --- Сетевая инфраструктура ---
resource "yandex_vpc_network" "k8s_network" {
  name = "k8s-network"
}

resource "yandex_vpc_subnet" "k8s_subnet" {
  name           = "k8s-subnet"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.k8s_network.id
  v4_cidr_blocks = ["10.1.0.0/16"]
}

# --- Сервисные аккаунты и права ---

# 1. Сервисный аккаунт для ресурсов кластера (Мастер)
resource "yandex_iam_service_account" "k8s_master_sa" {
  name = "k8s-master-sa"
}

resource "yandex_resourcemanager_folder_iam_member" "master_agent" {
  folder_id = yandex_iam_service_account.k8s_master_sa.folder_id
  role      = "k8s.clusters.agent"
  member    = "serviceAccount:${yandex_iam_service_account.k8s_master_sa.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "vpc_public_admin" {
  folder_id = yandex_iam_service_account.k8s_master_sa.folder_id
  role      = "vpc.publicAdmin"
  member    = "serviceAccount:${yandex_iam_service_account.k8s_master_sa.id}"
}

# 2. Сервисный аккаунт для Нод (скачивание образов)
resource "yandex_iam_service_account" "k8s_node_sa" {
  name = "k8s-node-sa"
}

resource "yandex_resourcemanager_folder_iam_member" "node_puller" {
  folder_id = yandex_iam_service_account.k8s_node_sa.folder_id
  role      = "container-registry.images.puller"
  member    = "serviceAccount:${yandex_iam_service_account.k8s_node_sa.id}"
}

# 3. Сервисный аккаунт для Object Storage (Бакет)
resource "yandex_iam_service_account" "bucket_sa" {
  name = "bucket-sa"
}

resource "yandex_resourcemanager_folder_iam_member" "bucket_editor" {
  folder_id = yandex_iam_service_account.bucket_sa.folder_id
  role      = "storage.editor"
  member    = "serviceAccount:${yandex_iam_service_account.bucket_sa.id}"
}

# Статический ключ для доступа CSI-драйвера к бакету
resource "yandex_iam_service_account_static_access_key" "bucket_sa_key" {
  service_account_id = yandex_iam_service_account.bucket_sa.id
  description        = "static access key for object storage csi"
}

# --- Создание бакета Object Storage ---
resource "yandex_storage_bucket" "k8s_s3_bucket" {
  access_key = yandex_iam_service_account_static_access_key.bucket_sa_key.access_key
  secret_key = yandex_iam_service_account_static_access_key.bucket_sa_key.secret_key
  bucket     = "otus-hw-bucket-${random_string.bucket_suffix.result}" # Бакет должен иметь уникальное имя
}

resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# --- Создание Managed Kubernetes кластера ---
resource "yandex_kubernetes_cluster" "k8s_cluster" {
  name       = "managed-k8s-cluster"
  network_id = yandex_vpc_network.k8s_network.id

  master {
    zonal {
      zone      = yandex_vpc_subnet.k8s_subnet.zone
      subnet_id = yandex_vpc_subnet.k8s_subnet.id
    }
    public_ip = true
  }

  service_account_id      = yandex_iam_service_account.k8s_master_sa.id
  node_service_account_id = yandex_iam_service_account.k8s_node_sa.id

  depends_on = [
    yandex_resourcemanager_folder_iam_member.master_agent,
    yandex_resourcemanager_folder_iam_member.vpc_public_admin
  ]
}

# Нод-группа кластера
resource "yandex_kubernetes_node_group" "k8s_node_group" {
  cluster_id = yandex_kubernetes_cluster.k8s_cluster.id
  name       = "k8s-node-group"

  instance_template {
    platform_id = "standard-v3"

    network_interface {
      nat        = true
      subnet_ids = [yandex_vpc_subnet.k8s_subnet.id]
    }

    resources {
      memory = 4
      cores  = 2
    }

    boot_disk {
      type = "network-hdd"
      size = 64
    }
  }

  scale_policy {
    fixed_scale {
      size = 1
    }
  }
}

# Вывод важных данных для K8s манифестов
output "bucket_name" {
  value = yandex_storage_bucket.k8s_s3_bucket.bucket
}

output "access_key" {
  value     = yandex_iam_service_account_static_access_key.bucket_sa_key.access_key
  sensitive = false # Сделано для удобства копирования в ДЗ
}

output "secret_key" {
  value     = yandex_iam_service_account_static_access_key.bucket_sa_key.secret_key
  sensitive = true
}