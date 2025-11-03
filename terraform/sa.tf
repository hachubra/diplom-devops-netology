resource "yandex_iam_service_account" "diplom-k8s-sa" {
  folder_id = var.folder_id
  name      = "terraform-service-account"
}

resource "yandex_resourcemanager_folder_iam_binding" "diplom-k8s-editor" {
  folder_id = var.folder_id
  role      = "editor"
  members = [
    "serviceAccount:${yandex_iam_service_account.diplom-k8s-sa.id}"
  ]
  depends_on = [
    yandex_iam_service_account.diplom-k8s-sa
  ]
}


resource "yandex_resourcemanager_folder_iam_binding" "diplom-k8s-compute-editor" {
  folder_id = var.folder_id
  role      = "compute.editor"
  members = [
    "serviceAccount:${yandex_iam_service_account.diplom-k8s-sa.id}"
  ]
  depends_on = [
    yandex_iam_service_account.diplom-k8s-sa
  ]
}


resource "yandex_resourcemanager_folder_iam_binding" "diplom-k8s-puller" {
  folder_id = var.folder_id
  role      = "container-registry.images.puller"
  members = [
    "serviceAccount:${yandex_iam_service_account.diplom-k8s-sa.id}",
    "system:allUsers"
  ]
  depends_on = [
    yandex_iam_service_account.diplom-k8s-sa
  ]
}

