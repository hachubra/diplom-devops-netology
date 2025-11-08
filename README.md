# Дипломный практикум в Yandex.Cloud
  * [Цели:](#цели)
  * [Этапы выполнения:](#этапы-выполнения)
     * [Создание облачной инфраструктуры](#создание-облачной-инфраструктуры)
     * [Создание Kubernetes кластера](#создание-kubernetes-кластера)
     * [Создание тестового приложения](#создание-тестового-приложения)
     * [Подготовка cистемы мониторинга и деплой приложения](#подготовка-cистемы-мониторинга-и-деплой-приложения)
     * [Установка и настройка CI/CD](#установка-и-настройка-cicd)
  * [Что необходимо для сдачи задания?](#что-необходимо-для-сдачи-задания)
  * [Как правильно задавать вопросы дипломному руководителю?](#как-правильно-задавать-вопросы-дипломному-руководителю)

**Перед началом работы над дипломным заданием изучите [Инструкция по экономии облачных ресурсов](https://github.com/netology-code/devops-materials/blob/master/cloudwork.MD).**

---
## Цели:

1. Подготовить облачную инфраструктуру на базе облачного провайдера Яндекс.Облако.
2. Запустить и сконфигурировать Kubernetes кластер.
3. Установить и настроить систему мониторинга.
4. Настроить и автоматизировать сборку тестового приложения с использованием Docker-контейнеров.
5. Настроить CI для автоматической сборки и тестирования.
6. Настроить CD для автоматического развёртывания приложения.

---
## Этапы выполнения:

### Создание облачной инфраструктуры
<details> <summary> Задача 1</summary>

Для начала необходимо подготовить облачную инфраструктуру в ЯО при помощи [Terraform](https://www.terraform.io/).

Особенности выполнения:

- Бюджет купона ограничен, что следует иметь в виду при проектировании инфраструктуры и использовании ресурсов;
Для облачного k8s используйте региональный мастер(неотказоустойчивый). Для self-hosted k8s минимизируйте ресурсы ВМ и долю ЦПУ. В обоих вариантах используйте прерываемые ВМ для worker nodes.

Предварительная подготовка к установке и запуску Kubernetes кластера.

1. Создайте сервисный аккаунт, который будет в дальнейшем использоваться Terraform для работы с инфраструктурой с необходимыми и достаточными правами. Не стоит использовать права суперпользователя
2. Подготовьте [backend](https://developer.hashicorp.com/terraform/language/backend) для Terraform:  
   а. Рекомендуемый вариант: S3 bucket в созданном ЯО аккаунте(создание бакета через TF)
   б. Альтернативный вариант:  [Terraform Cloud](https://app.terraform.io/)
3. Создайте конфигурацию Terrafrom, используя созданный бакет ранее как бекенд для хранения стейт файла. Конфигурации Terraform для создания сервисного аккаунта и бакета и основной инфраструктуры следует сохранить в разных папках.
4. Создайте VPC с подсетями в разных зонах доступности.
5. Убедитесь, что теперь вы можете выполнить команды `terraform destroy` и `terraform apply` без дополнительных ручных действий.
6. В случае использования [Terraform Cloud](https://app.terraform.io/) в качестве [backend](https://developer.hashicorp.com/terraform/language/backend) убедитесь, что применение изменений успешно проходит, используя web-интерфейс Terraform cloud.
</details>

<details> <summary> Ожидаемые результаты:</summary> 

1. Terraform сконфигурирован и создание инфраструктуры посредством Terraform возможно без дополнительных ручных действий, стейт основной конфигурации сохраняется в бакете или Terraform Cloud
2. Полученная конфигурация инфраструктуры является предварительной, поэтому в ходе дальнейшего выполнения задания возможны изменения.
</details>

#### Решение 1.

<details> <summary> Подготовка облачной инфраструктуры Terraform</summary> 

Создаем необходимые сервисные аккаунты в ЯО, создаем S3 bucket для хранения .tfstate, включаем шифрование, настраиваем использование tfstate в нашем S3 bucket для основного манифеста terraform с помощью шаблона.

<details> <summary> prep_bucket.tf: </summary> 

```yaml
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
```
</details>

Убеждаемся, что S3 bucket создан и шифрование включено:

![screenshot1](https://github.com/hachubra/diplom-devops-netology/blob/main/img/Screenshot_3.png)

</details>


<details> <summary> Развертывание облачной инфраструктуры Terraform</summary> 

 Подготавливаем манифесты для развертывания инфраструктуры для кластера k8s (сервисные аккаунты, сети, группы ВМ), переходим в ../terraform и создаем необходимые ресурсы в облаке:

```bash
terraform apply
```
В качестве вывода получаем файл inverntory.yml для последующего развертывания кластера k8s и вывод в косноль с адресами полученных ресурсов:

```bash
Outputs:

external_ip_control_plane = tolist([
  "46.21.245.41",
])
external_ip_nodes = tolist([
  "62.84.112.100",
  "89.169.180.46",
  "158.160.203.154",
])
```
![screenshot1](https://github.com/hachubra/diplom-devops-netology/blob/main/img/Screenshot_4.png)

проверяем, что tfstate хранится в S3 bucket:

![screenshot1](https://github.com/hachubra/diplom-devops-netology/blob/main/img/Screenshot_5.png)
</details>

---

### Создание Kubernetes кластера

<details> <summary> Задача 2 </summary>

На этом этапе необходимо создать [Kubernetes](https://kubernetes.io/ru/docs/concepts/overview/what-is-kubernetes/) кластер на базе предварительно созданной инфраструктуры.   Требуется обеспечить доступ к ресурсам из Интернета.

Это можно сделать двумя способами:

1. Рекомендуемый вариант: самостоятельная установка Kubernetes кластера.  
   а. При помощи Terraform подготовить как минимум 3 виртуальных машины Compute Cloud для создания Kubernetes-кластера. Тип виртуальной машины следует выбрать самостоятельно с учётом требовании к производительности и стоимости. Если в дальнейшем поймете, что необходимо сменить тип инстанса, используйте Terraform для внесения изменений.  
   б. Подготовить [ansible](https://www.ansible.com/) конфигурации, можно воспользоваться, например [Kubespray](https://kubernetes.io/docs/setup/production-environment/tools/kubespray/)  
   в. Задеплоить Kubernetes на подготовленные ранее инстансы, в случае нехватки каких-либо ресурсов вы всегда можете создать их при помощи Terraform.
2. Альтернативный вариант: воспользуйтесь сервисом [Yandex Managed Service for Kubernetes](https://cloud.yandex.ru/services/managed-kubernetes)  
  а. С помощью terraform resource для [kubernetes](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/kubernetes_cluster) создать **региональный** мастер kubernetes с размещением нод в разных 3 подсетях      
  б. С помощью terraform resource для [kubernetes node group](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/kubernetes_node_group)
  
</details>

<details><summary>Ожидаемый результат:</summary>

1. Работоспособный Kubernetes кластер.
2. В файле `~/.kube/config` находятся данные для доступа к кластеру.
3. Команда `kubectl get pods --all-namespaces` отрабатывает без ошибок.

</details>

#### Решение 2

<details><summary>Развертывание кластера Kubernetes</summary>
Развертывание кластера k8s производим с помощью kubespray:

```bash
git clone --depth=1 https://github.com/kubernetes-sigs/kubespray.git
```
```bash
sudo apt install python3-venv
```
```bash
python3 -m venv venv
```
```bash
source venv/bin/activate
```
```bash
pip install -U -r requirements.txt
```
```bash
ansible-playbook -i ../devops-diplom-yandexcloud/kubespray/inventory/diplom-k8s-cluster/inventory.yml cluster.yml -b --private-key ~/.ssh/new_key_kuber -u ubuntu
```

```bash
PLAY RECAP *******************************************************************************************************
control-plane              : ok=618  changed=137  unreachable=0    failed=0    skipped=990  rescued=0    ignored=5   
node-1                     : ok=425  changed=83   unreachable=0    failed=0    skipped=623  rescued=0    ignored=0   
node-2                     : ok=425  changed=83   unreachable=0    failed=0    skipped=622  rescued=0    ignored=0   
node-3                     : ok=425  changed=83   unreachable=0    failed=0    skipped=622  rescued=0    ignored=0
```

</details>

<details><summary>Проверка работы кластера Kubernetes</summary>

Копируем конфиг k8s с control-node:
```bash
ssh ubuntu@46.21.245.41 "sudo cat /etc/kubernetes/admin.conf" | tee $HOME/.kube/config
```
Устанавливаем разрешения для конфига:

```bash
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```
Меняем адрес для подключения к кластеру:
```bash
nano $HOME/.kube/config # меняем на IP адрес на адрес control-node
```

Проверяем работу кластера:
```bash
kubectl get pods --all-namespaces
```
Убеждаемся, что ошибок нет:
```bash
NAMESPACE     NAME                                       READY   STATUS    RESTARTS      AGE
kube-system   calico-kube-controllers-865dd69ff8-n2ljc   1/1     Running   0             10m
kube-system   calico-node-6xsbn                          1/1     Running   0             11m
kube-system   calico-node-brfj9                          1/1     Running   0             11m
kube-system   calico-node-qx2qk                          1/1     Running   0             11m
kube-system   calico-node-r5pm8                          1/1     Running   0             11m
kube-system   coredns-64b5cc5cbc-khm4f                   1/1     Running   0             10m
kube-system   coredns-64b5cc5cbc-zv2qn                   1/1     Running   0             10m
kube-system   dns-autoscaler-5594cbb9c4-d2gmf            1/1     Running   0             10m
kube-system   kube-apiserver-control-plane               1/1     Running   0             13m
kube-system   kube-controller-manager-control-plane      1/1     Running   2 (13m ago)   13m
kube-system   kube-proxy-6znxw                           1/1     Running   0             12m
kube-system   kube-proxy-dkwgq                           1/1     Running   0             12m
kube-system   kube-proxy-kxrmh                           1/1     Running   0             12m
kube-system   kube-proxy-w5w5v                           1/1     Running   0             12m
kube-system   kube-scheduler-control-plane               1/1     Running   1             13m
kube-system   nginx-proxy-node-1                         1/1     Running   0             12m
kube-system   nginx-proxy-node-2                         1/1     Running   0             12m
kube-system   nginx-proxy-node-3                         1/1     Running   0             12m
kube-system   nodelocaldns-4pzhh                         1/1     Running   0             10m
kube-system   nodelocaldns-qj6hp                         1/1     Running   0             10m
kube-system   nodelocaldns-rzlh4                         1/1     Running   0             10m
kube-system   nodelocaldns-tvgll                         1/1     Running   0             10m
```

</details>

---
### Создание тестового приложения

<details> <summary> Задача 3</summary>

Для перехода к следующему этапу необходимо подготовить тестовое приложение, эмулирующее основное приложение разрабатываемое вашей компанией.

Способ подготовки:

1. Рекомендуемый вариант:  
   а. Создайте отдельный git репозиторий с простым nginx конфигом, который будет отдавать статические данные.  
   б. Подготовьте Dockerfile для создания образа приложения.  
2. Альтернативный вариант:  
   а. Используйте любой другой код, главное, чтобы был самостоятельно создан Dockerfile.

</details> 

<details><summary>Ожидаемый результат:</summary>

1. Git репозиторий с тестовым приложением и Dockerfile.
2. Регистри с собранным docker image. В качестве регистри может быть DockerHub или [Yandex Container Registry](https://cloud.yandex.ru/services/container-registry), созданный также с помощью terraform.
</details> 

#### Решение 3
<details><summary>Репозиторий расположен по адресу:</summary>

https://github.com/hachubra/apptest.git

Dockerfile:

```yaml
FROM nginx:alpine

RUN rm -rf /usr/share/nginx/html/index.html
COPY ./myapp/index.html /usr/share/nginx/html/index.html

COPY ./myapp/nginx.conf /etc/nginx/nginx.conf

ENTRYPOINT ["nginx", "-g", "daemon off;"]
```

</details>

<details><summary>Создание Registry в Яндекс облаке.</summary>

Загрузка image в registry:

Получаем идентификатор registry
```bash
yc container registry get diplom-netology-registry
```
Собираем образ:

```bash
 docker build -t myapp-test .
```
Ставим тэг:
```bash
docker tag myapp-test:latest cr.yandex/crpp9acq3pqq72ip67ni/myapp-test:0.1
```
Загружаем image в registry
```bash
docker push cr.yandex/crpp9acq3pqq72ip67ni/myapp-test:0.1 
```

![screenshot1](https://github.com/hachubra/diplom-devops-netology/blob/main/img/Screenshot_6.png)

![screenshot1](https://github.com/hachubra/diplom-devops-netology/blob/main/img/Screenshot_7.png)

</details>


---
### Подготовка cистемы мониторинга и деплой приложения

<details> <summary> Задача 4</summary>

Уже должны быть готовы конфигурации для автоматического создания облачной инфраструктуры и поднятия Kubernetes кластера.  
Теперь необходимо подготовить конфигурационные файлы для настройки нашего Kubernetes кластера.

Цель:
1. Задеплоить в кластер [prometheus](https://prometheus.io/), [grafana](https://grafana.com/), [alertmanager](https://github.com/prometheus/alertmanager), [экспортер](https://github.com/prometheus/node_exporter) основных метрик Kubernetes.
2. Задеплоить тестовое приложение, например, [nginx](https://www.nginx.com/) сервер отдающий статическую страницу.

</details>
<details> <summary> Способ выполнения:</summary>

1. Воспользоваться пакетом [kube-prometheus](https://github.com/prometheus-operator/kube-prometheus), который уже включает в себя [Kubernetes оператор](https://operatorhub.io/) для [grafana](https://grafana.com/), [prometheus](https://prometheus.io/), [alertmanager](https://github.com/prometheus/alertmanager) и [node_exporter](https://github.com/prometheus/node_exporter). Альтернативный вариант - использовать набор helm чартов от [bitnami](https://github.com/bitnami/charts/tree/main/bitnami).

</details>

#### Решение 4

<details><summary>Подготовка Service и Deployment для тестового приложения</summary>
Deployment:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: apptest
  namespace: nsapptest
  labels:
    app: apptest
  annotations:
    kubernetes.io/change-cause: "first"
spec:
  replicas: 3
  revisionHistoryLimit: 5
  strategy:
    rollingUpdate:
      maxSurge: 80%
      maxUnavailable: 80%
  selector:
    matchLabels:
      app: apptest
  template:
    metadata:
      labels:
        app: apptest
    spec:
      containers:
      - name: nginx
        image: cr.yandex/crpp9acq3pqq72ip67ni/myapp-test:0.1
        ports:
        - containerPort: 80
        
```
ns:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: nsapptest
```
service:

```yaml

# apptest
apiVersion: v1
kind: Service
metadata:
  name: svc-apptest
  namespace: nsapptest
spec:
  type: NodePort
  selector:
    app: apptest
  ports:
    - name: web-app
      nodePort: 30999
      port: 80
      targetPort: 80

```

</details>

<details><summary>Добавление NLB</summary>
Описываем манифест для NLB в terraform: 
<details> <summary>manifest</summary>

```yaml
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
```
</details>

</details>

<details><summary>Деплой тестового приложения</summary>

```bash
kubectl apply -f deploy/ns.yml
kubectl apply -f deploy/
```
```bash
kubectl get po -n nsapptest 
```
```bash
NAME                     READY   STATUS    RESTARTS   AGE
apptest-bd656c77-ccp8p   1/1     Running   0          7s
apptest-bd656c77-llfcv   1/1     Running   0          7s
apptest-bd656c77-nxdjn   1/1     Running   0          7s
```

![screenshot1](https://github.com/hachubra/diplom-devops-netology/blob/main/img/Screenshot_8.png)
![screenshot1](https://github.com/hachubra/diplom-devops-netology/blob/main/img/Screenshot_9.png)

</details>


<details><summary>Деплой kube-prometheus</summary>
Воспользуемся https://github.com/prometheus-operator/kube-prometheus для деплоя в наш k8s кластер.

Откорректируем манифест grafana-service.yaml
```yaml
apiVersion: v1
kind: Service
metadata:
  labels:
    app.kubernetes.io/component: grafana
    app.kubernetes.io/name: grafana
    app.kubernetes.io/part-of: kube-prometheus
    app.kubernetes.io/version: 12.2.0
  name: grafana
  namespace: monitoring
spec:
  type: NodePort
  selector:
    app.kubernetes.io/component: grafana
    app.kubernetes.io/name: grafana
    app.kubernetes.io/part-of: kube-prometheus
  ports:
    - name: http
      nodePort: 30300
      port: 3000
      targetPort: 3000
```

Установим проект:

```bash
kubectl apply --server-side -f manifests/setup
kubectl wait \
    --for condition=Established \
    --all CustomResourceDefinition \
    --namespace=monitoring
kubectl apply -f manifests/
```

Проверим что все развернулось:

```bash
kubectl get po -n monitoring 
```
```bash
NAME                                   READY   STATUS    RESTARTS   AGE
alertmanager-main-0                    2/2     Running   0          57s
alertmanager-main-1                    2/2     Running   0          57s
alertmanager-main-2                    2/2     Running   0          57s
blackbox-exporter-6748c6f6b9-9m2g9     3/3     Running   0          83s
grafana-5bc7ffb8c5-6k665               1/1     Running   0          77s
kube-state-metrics-7cff856cb4-6dsr8    3/3     Running   0          76s
node-exporter-9z9mf                    2/2     Running   0          75s
node-exporter-h9f4m                    2/2     Running   0          75s
node-exporter-kv9vg                    2/2     Running   0          75s
node-exporter-srwwz                    2/2     Running   0          75s
prometheus-adapter-6c5fcc994f-jdrlr    1/1     Running   0          72s
prometheus-adapter-6c5fcc994f-zbnjm    1/1     Running   0          72s
prometheus-k8s-0                       2/2     Running   0          57s
prometheus-k8s-1                       2/2     Running   0          57s
prometheus-operator-66cffd595f-p7fx8   2/2     Running   0          71s
```
Проверим, что grafana доступна из интернета:

![screenshot1](https://github.com/hachubra/diplom-devops-netology/blob/main/img/Screenshot_10.png)
![screenshot1](https://github.com/hachubra/diplom-devops-netology/blob/main/img/Screenshot_11.png)

</details>


### Деплой инфраструктуры в terraform pipeline   </summary>

<details> <summary> Задача 5 </summary>

1. Если на первом этапе вы не воспользовались [Terraform Cloud](https://app.terraform.io/), то задеплойте и настройте в кластере [atlantis](https://www.runatlantis.io/) для отслеживания изменений инфраструктуры. Альтернативный вариант 3 задания: вместо Terraform Cloud или atlantis настройте на автоматический запуск и применение конфигурации terraform из вашего git-репозитория в выбранной вами CI-CD системе при любом комите в main ветку. Предоставьте скриншоты работы пайплайна из CI/CD системы.
</details> 

<details> <summary> Ожидаемый результат:  </summary>

1. Git репозиторий с конфигурационными файлами для настройки Kubernetes.
2. Http доступ на 80 порту к web интерфейсу grafana.
3. Дашборды в grafana отображающие состояние Kubernetes кластера.
4. Http доступ на 80 порту к тестовому приложению.
5. Atlantis или terraform cloud или ci/cd-terraform
</details> 

#### Решение 5

<details><summary>сменим настройки NLB для Grafana</summary>

Изменим манифест, чтобы NLB для Grafana слушал 80 порт:

```yaml
resource "yandex_lb_network_load_balancer" "nlb-grf" {

  name = "nlb-diplom-grafana"

  listener {
    name        = "grafana-listener"
    port        = 80
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
```
</details>



Для автоматического применения конфигурации terraform воспользуемся github actions. Для этого создадим workflow.

<details><summary>workflow:</summary>

```yaml
name: Deploy to Yandex Cloud

on:
  push:
    branches:
      - main

jobs:
  deploy:
    runs-on: ubuntu-latest
    env:
      working-directory: terraform/
    defaults:
      run:
        working-directory: ${{ env.working-directory }}
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: IAM Token
        id: issue-iam-token
        uses: yc-actions/yc-iam-token@v1
        with:
          yc-sa-json-credentials: ${{ secrets.YCAUTHKEYJSON }}
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v1
        with:
          terraform_version: 1.9.4
          
      - name: Terraform Init
        id: init
        run: terraform init -backend-config="access_key=${{ secrets.YCACCESSKEY }}" -backend-config="secret_key=${{ secrets.YCSECRETKEY }}" -var "token=${{ secrets.YCOAUTHTOKEN }}" 

      - name: Terraform Plan
        id: plan
        run: terraform plan -var "token=${{ secrets.YCOAUTHTOKEN }}" -var "SSHKEY=${{ secrets.SSHKEY }}"  -out plan.tfplan
        
      - name: Terraform Plan Status
        if: steps.plan.outcome == 'failure'
        run: exit 1

      - name: Terraform Apply
        run: terraform apply  -auto-approve plan.tfplan
```
</details>

Git репозиторий: https://github.com/hachubra/apptest.git

Выполение задачи при коммите в репозиторий: 

![screenshot1](https://github.com/hachubra/diplom-devops-netology/blob/main/img/Screenshot_12.png)


---
### Установка и настройка CI/CD 
<details> <summary> Задача 6</summary>

Осталось настроить ci/cd систему для автоматической сборки docker image и деплоя приложения при изменении кода.

Цель:

1. Автоматическая сборка docker образа при коммите в репозиторий с тестовым приложением.
2. Автоматический деплой нового docker образа.

Можно использовать [teamcity](https://www.jetbrains.com/ru-ru/teamcity/), [jenkins](https://www.jenkins.io/), [GitLab CI](https://about.gitlab.com/stages-devops-lifecycle/continuous-integration/) или GitHub Actions.

</details> 

<details> <summary> Ожидаемый результат: </summary>

1. Интерфейс ci/cd сервиса доступен по http.
2. При любом коммите в репозиторие с тестовым приложением происходит сборка и отправка в регистр Docker образа.
3. При создании тега (например, v1.0.0) происходит сборка и отправка с соответствующим label в регистри, а также деплой соответствующего Docker образа в кластер Kubernetes.
</details>

#### Решение 6

<details><summary> zzzzz </summary>

</details>

<details><summary>яяяя</summary>

</details>

<details><summary>яяяя</summary>

</details>


---
## Что необходимо для сдачи задания?

<details><summary> Итоговые требования</summary>

1. Репозиторий с конфигурационными файлами Terraform и готовность продемонстрировать создание всех ресурсов с нуля.
2. Пример pull request с комментариями созданными atlantis'ом или снимки экрана из Terraform Cloud или вашего CI-CD-terraform pipeline.
3. Репозиторий с конфигурацией ansible, если был выбран способ создания Kubernetes кластера при помощи ansible.
4. Репозиторий с Dockerfile тестового приложения и ссылка на собранный docker image.
5. Репозиторий с конфигурацией Kubernetes кластера.
6. Ссылка на тестовое приложение и веб интерфейс Grafana с данными доступа.
7. Все репозитории рекомендуется хранить на одном ресурсе (github, gitlab)

</details>

#### Итоговые ссылки

<details><summary> zzzzz </summary>
ву
</details>

