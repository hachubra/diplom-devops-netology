resource "yandex_vpc_network" "network" {
  name = "network"
  description = "Network for diplom project"
}

resource "yandex_vpc_subnet" "subnet" {
  for_each = {
    for k,v in var.subnets :
      v.zone => v
  }
  name           = "subnet-${each.value.zone}"
  zone           = "${each.value.zone}"
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = ["${each.value.cidr}"]
}

resource "yandex_lb_target_group" "nlb-group-diplom" {

  name       = "nlb-group-diplom"
  depends_on = [yandex_compute_instance_group.diplom-ks8-nodes]

  dynamic "target" {
    for_each = yandex_compute_instance_group.diplom-ks8-nodes.instances
    content {
      subnet_id = target.value.network_interface.0.subnet_id
      address   = target.value.network_interface.0.ip_address
    }
  }
}

resource "yandex_lb_network_load_balancer" "nlb-grf" {

  name = "nlb-diplom-grafana"

  listener {
    name        = "grafana-listener"
    port        = 3000
    target_port = 30300
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_lb_target_group.nlb-group-diplom.id

    healthcheck {
      name = "healthcheck"
      tcp_options {
        port = 30300
      }
    }
  }
  depends_on = [yandex_lb_target_group.nlb-group-diplom]
}

resource "yandex_lb_network_load_balancer" "nlb-apptest" {

  name = "nlb-diplom-k8s-apptest"

  listener {
    name        = "app-listener"
    port        = 80
    target_port = 30999
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_lb_target_group.nlb-group-diplom.id

    healthcheck {
      name = "healthcheck"
      tcp_options {
        port = 30999
      }
    }
  }
  depends_on = [yandex_lb_target_group.nlb-group-diplom]
}