#control node

resource "yandex_compute_instance_group" "diplom-ks8-master" {
  name                = "diplom-ks8-master"
  folder_id           = var.folder_id
  service_account_id  = yandex_iam_service_account.diplom-k8s-sa.id
  deletion_protection = "false"
  instance_template {
    name = "master-{instance.index}"
    platform_id = "standard-v2"
    resources {
      memory = var.vms_resources.nodes.memory
      cores  = var.vms_resources.nodes.cores
      core_fraction = var.vms_resources.nodes.core_fraction
    }
    boot_disk {
      mode = "READ_WRITE"
      initialize_params {
        image_id = var.vms_resources.nodes.image
        size     = var.vms_resources.nodes.boot_disk_size
      }
    }
    scheduling_policy {
        preemptible = var.vm_nodes_preemptible
    }

    network_interface {
      subnet_ids = toset(values(local.subnet_ids)) 
      nat = var.vm_nodes_nat
    }
        metadata = {
          ssh-keys = "ubuntu:${file("~/.ssh/new_key_kuber.pub")}"
        }
  }  
    scale_policy {
      fixed_scale {
        size = var.vm_master_count
      }
    }

    allocation_policy {
      zones = ["ru-central1-a"]
    }

    deploy_policy {
    max_unavailable = 1
    max_expansion   = 0
    }
  depends_on = [
    yandex_resourcemanager_folder_iam_binding.diplom-k8s-compute-editor
  ]
}

#worker nodes

resource "yandex_compute_instance_group" "diplom-ks8-nodes" {
  name                = "diplom-ks8-nodes"
  folder_id           = var.folder_id
  service_account_id  = yandex_iam_service_account.diplom-k8s-sa.id
  deletion_protection = "false"
  instance_template {
    name = "node-{instance.index}"
    platform_id = "standard-v2"
    resources {
      memory = var.vms_resources.nodes.memory
      cores  = var.vms_resources.nodes.cores
      core_fraction = var.vms_resources.nodes.core_fraction
    }
    boot_disk {
      mode = "READ_WRITE"
      initialize_params {
        image_id = var.vms_resources.nodes.image
        size     = var.vms_resources.nodes.boot_disk_size
      }
    }
    scheduling_policy {
        preemptible = var.vm_nodes_preemptible
    }

    network_interface {
      subnet_ids = toset(values(local.subnet_ids)) 
      nat = var.vm_nodes_nat
    }
        metadata = {
          ssh-keys = "ubuntu:${file("~/.ssh/new_key_kuber.pub")}"
        }
  }  
    scale_policy {
      fixed_scale {
        size = var.vm_nodes_count
      }
    }

    allocation_policy {
      zones = [
        "ru-central1-a",
        "ru-central1-b",
        "ru-central1-d"
      ]
    }

    deploy_policy {
    max_unavailable = 3
    max_expansion   = 0
    }
  depends_on = [
    yandex_resourcemanager_folder_iam_binding.diplom-k8s-compute-editor
  ]
}