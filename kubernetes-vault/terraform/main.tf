terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = ">= 0.100.0"
    }
  }
  required_version = ">= 1.3.0"
}

provider "yandex" {
  token     = var.yc_token  # <--- Теперь Терраформ будет искать токен здесь
  folder_id = var.folder_id
}

# ==============================================================================
# СЕТЕВАЯ ИНФРАСТРУКТУРА
# ==============================================================================

resource "yandex_vpc_network" "k8s_network" {
  name        = "k8s-network"
  description = "Сеть для Kubernetes кластера"
}

resource "yandex_vpc_subnet" "k8s_subnet" {
  name           = "k8s-subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.k8s_network.id
  v4_cidr_blocks = ["10.128.0.0/24"]
}

# ==============================================================================
# СЕРВИСНЫЕ АККАУНТЫ И РОЛИ
# ==============================================================================

# Сервисный аккаунт для управления кластером (инфраструктурный)
resource "yandex_iam_service_account" "k8s_master_sa" {
  name        = "k8s-master-sa"
  description = "Сервисный аккаунт для управления ресурсами кластера K8s"
}

resource "yandex_resourcemanager_folder_iam_member" "master_roles" {
  for_each  = toset(["k8s.clusters.agent", "vpc.publicAdmin", "container-registry.images.puller"])
  folder_id = var.folder_id
  role      = each.value
  member    = "serviceAccount:${yandex_iam_service_account.k8s_master_sa.id}"
}

# Сервисный аккаунт для воркер-нод (чтобы они могли, например, тянуть логи)
resource "yandex_iam_service_account" "k8s_node_sa" {
  name        = "k8s-node-sa"
  description = "Сервисный аккаунт для воркер-нод Kubernetes"
}

resource "yandex_resourcemanager_folder_iam_member" "node_roles" {
  for_each  = toset(["container-registry.images.puller", "k8s.clusters.agent"])
  folder_id = var.folder_id
  role      = each.value
  member    = "serviceAccount:${yandex_iam_service_account.k8s_node_sa.id}"
}

# ==============================================================================
# KUBERNETES MASTER (КЛАСТЕР)
# ==============================================================================

resource "yandex_kubernetes_cluster" "k8s_cluster" {
  name        = "yc-k8s-cluster"
  description = "Managed Kubernetes кластер"
  network_id  = yandex_vpc_network.k8s_network.id

  master {
    #version = "1.32"# Актуальная версия на текущий момент
    zonal {
      zone      = yandex_vpc_subnet.k8s_subnet.zone
      subnet_id = yandex_vpc_subnet.k8s_subnet.id
    }
    public_ip = true # Включаем публичный IP, чтобы можно было подключиться через kubectl
  }

  service_account_id      = yandex_iam_service_account.k8s_master_sa.id
  node_service_account_id = yandex_iam_service_account.k8s_node_sa.id

  depends_on = [
    yandex_resourcemanager_folder_iam_member.master_roles,
    yandex_resourcemanager_folder_iam_member.node_roles
  ]
}

# ==============================================================================
# ГРУППА ВОРКЕР-НОД (3 узла)
# ==============================================================================

resource "yandex_kubernetes_node_group" "k8s_node_group" {
  cluster_id  = yandex_kubernetes_cluster.k8s_cluster.id
  name        = "k8s-worker-group"
  description = "Группа воркер-нод"
  #version     = "1.28"

  instance_template {
    platform_id = "standard-v3" # Третье поколение процессоров (Intel Ice Lake)

    network_interface {
      nat        = true # Каждой ноде будет назначен публичный IP (опционально)
      subnet_ids = [yandex_vpc_subnet.k8s_subnet.id]
    }

    resources {
      memory = 4 # ГБ RAM
      cores  = 2 # vCPU
    }

    boot_disk {
      type = "network-ssd"
      size = 64 # ГБ
    }

    scheduling_policy {
      preemptible = false # Сделай true, если хочешь прерываемые ноды для экономии
    }

    container_runtime {
      type = "containerd"
    }

    # Сюда можно прокинуть свой SSH-ключ для дебага нод
    # metadata = {
    #   ssh-keys = "ubuntu:${file("C:/Users/perfe/.ssh/id_ed25519.pub")}"
    # }
  }

  scale_policy {
    fixed_scale {
      size = 3 # Ровно 3 воркер-ноды
    }
  }

  allocation_policy {
    location {
      zone = "ru-central1-a"
    }
  }
}