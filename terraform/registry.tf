//
// Create a new Container Registry.
//
resource "yandex_container_registry" "diplom-registry" {
  name      = "diplom-netology-registry"
  folder_id = var.folder_id

  labels = {
    my-label = "diplom-netology"
  }
}
