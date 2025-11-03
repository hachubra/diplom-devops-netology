resource "yandex_iam_service_account" "mysa" {
  folder_id = var.folder_id
  name = "my-bucket"
}

resource "yandex_resourcemanager_folder_iam_member" "mysa-editor" {
  folder_id = var.folder_id
  role      = "storage.editor"
  member    = "serviceAccount:${yandex_iam_service_account.mysa.id}"
}


resource "yandex_resourcemanager_folder_iam_member" "mysa-encrypterDecrypter" {
  folder_id = var.folder_id
  role      = "kms.keys.encrypterDecrypter"
  member    = "serviceAccount:${yandex_iam_service_account.mysa.id}"
}

resource "yandex_kms_symmetric_key" "my-key" {
  name              = "mycrypokey"
  description       = "encryption for a bucket"
  default_algorithm = "AES_256"
  rotation_period   = "8760h"
}

resource "yandex_iam_service_account_static_access_key" "mysa-static-key" {
  service_account_id = yandex_iam_service_account.mysa.id
  description        = "static access key for object storage"
}

resource "yandex_storage_bucket" "bucket" {
  access_key = yandex_iam_service_account_static_access_key.mysa-static-key.access_key
  secret_key = yandex_iam_service_account_static_access_key.mysa-static-key.secret_key
  bucket     = "diplom-state-bucket"
    server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = yandex_kms_symmetric_key.my-key.id
        sse_algorithm     = "aws:kms"
      }
    }
  }
}

data "yandex_iam_policy" "editor" {
  binding {
    role = "storage.editor"

    members = [
      "userAccount:${yandex_iam_service_account.mysa.id}",
    ]
  }
}

resource "yandex_iam_service_account_iam_policy" "editor-account-iam" {
  service_account_id = "${yandex_iam_service_account.mysa.id}"
  policy_data        = "${data.yandex_iam_policy.editor.policy_data}"
}

resource "local_file" "providers" { 
  content = templatefile("../terraform/template/providers.tftpl", {
    bucket_name = "diplom-state-bucket"
    access_key  = yandex_iam_service_account_static_access_key.mysa-static-key.access_key
    secret_key  = yandex_iam_service_account_static_access_key.mysa-static-key.secret_key
    cloud_id    = var.cloud_id
    folder_id   = var.folder_id
  })
  filename = "../terraform/providers.tf"
}