variable "token" {
  type        = string
  description = "OAuth-token; https://cloud.yandex.ru/docs/iam/concepts/authorization/oauth-token"
}

variable "cloud_id" {
  type        = string
  default     = "b1g1li51c4ebgmu7e9s6"
  description = "https://cloud.yandex.ru/docs/resource-manager/operations/cloud/get-id"
}

variable "folder_id" {
  type        = string
  default     = "b1gbldqcbvmq6hh0agh0"
  description = "https://cloud.yandex.ru/docs/resource-manager/operations/folder/get-id"
}

variable "default_zone" {
  type        = string
  default     = "ru-central1-a"
  description = "https://cloud.yandex.ru/docs/overview/concepts/geo-scope"
}

variable "subnets" {
  type = list(object({
    zone = string
    cidr = string
  }))
  default = [
    { zone = "ru-central1-a", cidr = "10.0.10.0/24" },
    { zone = "ru-central1-b", cidr = "10.0.20.0/24" },
    { zone = "ru-central1-d", cidr = "10.0.30.0/24" },
  ]
}


variable "vm_nodes_preemptible" {
  type        = bool
  default     = true
  description = "Yandex compute VM preemptible"
}

variable "vm_nodes_nat" {
  type        = bool
  default     = true
  description = "Yandex compute VM nat"
}

variable "vm_master_count" {
  type        = string
  default     = "1"
  description = "Yandex compute nodes count"
}

variable "vm_nodes_count" {
  type        = string
  default     = "3"
  description = "Yandex compute nodes count"
}


variable "vms_resources" {
    type = map (object({
        cores  = number
        memory = number
        core_fraction = number
        boot_disk_type  = string
        boot_disk_size  = number
        image = string

    }))
    default = {
        nodes={
            cores=4
            memory=4
            core_fraction=20
            boot_disk_type="network-ssd"
            boot_disk_size=20
            image = "fd86rorl7r6l2nq3ate6" #ubuntu 24.04
        }  
    }    
}

locals {
  key = file("~/.ssh/new_key_kuber.pub")
  subnet_ids = {
      for k, v in yandex_vpc_subnet.subnet : v.zone => v.id 
  }
  
}

variable "metadata" {
    type = map (object({
        serial_port = number
    }))
    default = {
        all={
            serial_port=1
        }
    }    
}

