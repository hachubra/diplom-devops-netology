
output "external_ip_control_plane" {
  value = yandex_compute_instance_group.diplom-ks8-master.instances[*].network_interface[0].nat_ip_address
}

output "external_ip_nodes" {
  value = yandex_compute_instance_group.diplom-ks8-nodes.instances[*].network_interface[0].nat_ip_address
}

output "registry_id" {
value = yandex_container_registry.diplom-registry.registry_id
}


resource "local_file" "k8s_nodes_ip" {
  content  = <<-EOF
---
all:
  hosts:
    control-plane:
      ansible_host: ${yandex_compute_instance_group.diplom-ks8-master.instances[0].network_interface.0.nat_ip_address}
      ansible_user: ubuntu
    node-1:
      ansible_host: ${yandex_compute_instance_group.diplom-ks8-nodes.instances[0].network_interface.0.nat_ip_address}
      ansible_user: ubuntu
    node-2:
      ansible_host: ${yandex_compute_instance_group.diplom-ks8-nodes.instances[1].network_interface.0.nat_ip_address}
      ansible_user: ubuntu
    node-3:
      ansible_host: ${yandex_compute_instance_group.diplom-ks8-nodes.instances[2].network_interface.0.nat_ip_address}
      ansible_user: ubuntu
  children:
    kube_control_plane:
      hosts:
        control-plane:
    kube_node:
      hosts:
        node-1:
        node-2:
        node-3:
    etcd:
      hosts:
        control-plane:
    k8s_cluster:
      vars:
        supplementary_addresses_in_ssl_keys: [${yandex_compute_instance_group.diplom-ks8-master.instances[0].network_interface.0.nat_ip_address}]
      children:
        kube_control_plane:
        kube_node:
    calico_rr:
      hosts: {}
    EOF
  filename = "../kubespray/inventory/diplom-k8s-cluster/inventory.yml"
}

