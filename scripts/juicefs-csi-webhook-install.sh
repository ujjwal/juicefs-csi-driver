#!/bin/bash

#
# Copyright 2022 Juicedata Inc
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

print_usage() {
  echo "Usage:"
  echo "    $0 COMMAND [OPTIONS]"
  echo "COMMAND:"
  echo "    help"
  echo "        Display this help message."
  echo "    install"
  echo "        Install JuiceFS CSI Driver in webhook mode."
  echo "    print"
  echo "        Print YAMLs of JuiceFS CSI Driver in webhook mode."
}

function gen_webhook_manifests() {
  need_cmd mktemp
  need_cmd openssl
  need_cmd curl

  K8S_SERVICE="juicefs-admission-webhook"
  K8S_NAMESPACE="kube-system"

  tmpdir=$(mktemp -d)

  ensure openssl genrsa -out ${tmpdir}/ca.key 2048 >/dev/null 2>&1
  ensure openssl req -x509 -new -nodes -key ${tmpdir}/ca.key -subj "/CN=${K8S_SERVICE}.${K8S_NAMESPACE}.svc" -days 1875 -out ${tmpdir}/ca.crt >/dev/null 2>&1
  ensure openssl genrsa -out ${tmpdir}/server.key 2048 >/dev/null 2>&1

  cat <<EOF >${tmpdir}/csr.conf
[req]
prompt = no
req_extensions = v3_req
distinguished_name = dn
[dn]
CN = ${K8S_SERVICE}.${K8S_NAMESPACE}.svc
[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
[alt_names]
DNS.1 = ${K8S_SERVICE}
DNS.2 = ${K8S_SERVICE}.${K8S_NAMESPACE}
DNS.3 = ${K8S_SERVICE}.${K8S_NAMESPACE}.svc
EOF

  ensure openssl req -new -key ${tmpdir}/server.key -out ${tmpdir}/server.csr -config ${tmpdir}/csr.conf >/dev/null 2>&1
  ensure openssl x509 -req -in ${tmpdir}/server.csr -CA ${tmpdir}/ca.crt -CAkey ${tmpdir}/ca.key -CAcreateserial -out ${tmpdir}/server.crt -days 1875 -extensions v3_req -extfile ${tmpdir}/csr.conf >/dev/null 2>&1

  TLS_KEY=$(openssl base64 -A -in ${tmpdir}/server.key)
  TLS_CRT=$(openssl base64 -A -in ${tmpdir}/server.crt)
  CA_BUNDLE=$(openssl base64 -A -in ${tmpdir}/ca.crt)

  # webhook.yaml start
  cat <<\EOF >${tmpdir}/webhook.yaml
# DO NOT EDIT: generated by 'kustomize build'
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    app.kubernetes.io/instance: juicefs-csi-driver
    app.kubernetes.io/name: juicefs-csi-driver
    app.kubernetes.io/version: master
  name: juicefs-csi-controller-sa
  namespace: kube-system
---
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    app.kubernetes.io/instance: juicefs-csi-driver
    app.kubernetes.io/name: juicefs-csi-driver
    app.kubernetes.io/version: master
  name: juicefs-csi-dashboard-sa
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  labels:
    app.kubernetes.io/instance: juicefs-csi-driver
    app.kubernetes.io/name: juicefs-csi-driver
    app.kubernetes.io/version: master
  name: juicefs-csi-dashboard-role
rules:
- apiGroups:
  - ""
  resources:
  - pods
  - persistentvolumes
  - persistentvolumeclaims
  - persistentvolumeclaims/status
  - nodes
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - storage.k8s.io
  resources:
  - storageclasses
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - ""
  resources:
  - events
  verbs:
  - get
  - list
  - watch
  - create
  - update
  - patch
- apiGroups:
  - ""
  resources:
  - pods/log
  verbs:
  - get
- apiGroups:
  - batch
  resources:
  - jobs
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - ""
  resources:
  - nodes/proxy
  verbs:
  - '*'
- apiGroups:
  - ""
  resources:
  - persistentvolumes
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - coordination.k8s.io
  resources:
  - leases
  verbs:
  - get
  - watch
  - list
  - delete
  - update
  - create
- apiGroups:
  - ""
  resources:
  - configmaps
  verbs:
  - get
  - watch
  - list
  - delete
  - update
  - create
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  labels:
    app.kubernetes.io/instance: juicefs-csi-driver
    app.kubernetes.io/name: juicefs-csi-driver
    app.kubernetes.io/version: master
  name: juicefs-external-provisioner-role
rules:
- apiGroups:
  - ""
  resources:
  - persistentvolumes
  verbs:
  - get
  - list
  - watch
  - create
  - delete
  - patch
- apiGroups:
  - ""
  resources:
  - persistentvolumeclaims
  - persistentvolumeclaims/status
  verbs:
  - get
  - list
  - watch
  - update
  - patch
- apiGroups:
  - storage.k8s.io
  resources:
  - storageclasses
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - ""
  resources:
  - events
  verbs:
  - list
  - watch
  - create
  - update
  - patch
- apiGroups:
  - storage.k8s.io
  resources:
  - csinodes
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - ""
  resources:
  - nodes
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - ""
  resources:
  - secrets
  verbs:
  - get
  - list
  - watch
  - create
  - update
  - patch
  - delete
- apiGroups:
  - ""
  resources:
  - pods
  - pods/log
  verbs:
  - get
  - list
  - watch
  - create
  - update
  - patch
  - delete
- apiGroups:
  - batch
  resources:
  - jobs
  verbs:
  - get
  - create
  - update
  - patch
  - delete
  - list
  - watch
- apiGroups:
  - ""
  resources:
  - endpoints
  verbs:
  - get
  - list
  - watch
  - create
  - update
  - patch
- apiGroups:
  - apps
  resources:
  - daemonsets
  verbs:
  - get
  - list
- apiGroups:
  - coordination.k8s.io
  resources:
  - leases
  verbs:
  - get
  - watch
  - list
  - delete
  - update
  - create
- apiGroups:
  - ""
  resources:
  - configmaps
  verbs:
  - get
  - watch
  - list
  - delete
  - update
  - create
- apiGroups:
  - ""
  resources:
  - pods/exec
  verbs:
  - '*'
- apiGroups:
  - apps
  resources:
  - statefulsets
  verbs:
  - get
- apiGroups:
  - apps
  resources:
  - replicasets
  verbs:
  - get
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  labels:
    app.kubernetes.io/instance: juicefs-csi-driver
    app.kubernetes.io/name: juicefs-csi-driver
    app.kubernetes.io/version: master
  name: juicefs-csi-dashboard-rolebinding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: juicefs-csi-dashboard-role
subjects:
- kind: ServiceAccount
  name: juicefs-csi-dashboard-sa
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  labels:
    app.kubernetes.io/instance: juicefs-csi-driver
    app.kubernetes.io/name: juicefs-csi-driver
    app.kubernetes.io/version: master
  name: juicefs-csi-provisioner-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: juicefs-external-provisioner-role
subjects:
- kind: ServiceAccount
  name: juicefs-csi-controller-sa
  namespace: kube-system
---
apiVersion: v1
data:
  ca.crt: CA_BUNDLE
  tls.crt: TLS_CRT
  tls.key: TLS_KEY
kind: Secret
metadata:
  labels:
    app.kubernetes.io/component: webhook-secret
    app.kubernetes.io/instance: juicefs-csi-driver
    app.kubernetes.io/name: juicefs-csi-driver
    app.kubernetes.io/version: master
  name: juicefs-webhook-certs
  namespace: kube-system
type: Opaque
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app.kubernetes.io/instance: juicefs-csi-driver
    app.kubernetes.io/name: juicefs-csi-driver
    app.kubernetes.io/version: master
  name: juicefs-admission-webhook
  namespace: kube-system
spec:
  ports:
  - name: https-rest
    port: 443
    targetPort: 9444
  selector:
    app: juicefs-csi-controller
    app.kubernetes.io/instance: juicefs-csi-driver
    app.kubernetes.io/name: juicefs-csi-driver
    app.kubernetes.io/version: master
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app.kubernetes.io/component: dashboard
    app.kubernetes.io/instance: juicefs-csi-driver
    app.kubernetes.io/name: juicefs-csi-driver
    app.kubernetes.io/version: master
  name: juicefs-csi-dashboard
  namespace: kube-system
spec:
  ports:
  - name: http
    port: 8088
    protocol: TCP
    targetPort: 8088
  selector:
    app: juicefs-csi-dashboard
    app.kubernetes.io/instance: juicefs-csi-driver
    app.kubernetes.io/name: juicefs-csi-driver
    app.kubernetes.io/version: master
  type: ClusterIP
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app.kubernetes.io/component: dashboard
    app.kubernetes.io/instance: juicefs-csi-driver
    app.kubernetes.io/name: juicefs-csi-driver
    app.kubernetes.io/version: master
  name: juicefs-csi-dashboard
  namespace: kube-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: juicefs-csi-dashboard
      app.kubernetes.io/instance: juicefs-csi-driver
      app.kubernetes.io/name: juicefs-csi-driver
      app.kubernetes.io/version: master
  template:
    metadata:
      labels:
        app: juicefs-csi-dashboard
        app.kubernetes.io/instance: juicefs-csi-driver
        app.kubernetes.io/name: juicefs-csi-driver
        app.kubernetes.io/version: master
    spec:
      containers:
      - args:
        - --static-dir=/dist
        env:
        - name: SYS_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        image: juicedata/csi-dashboard:v0.23.5
        name: dashboard
        ports:
        - containerPort: 8088
        resources:
          limits:
            cpu: 1000m
            memory: 1Gi
          requests:
            cpu: 100m
            memory: 200Mi
      serviceAccountName: juicefs-csi-dashboard-sa
      tolerations:
      - key: CriticalAddonsOnly
        operator: Exists
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  labels:
    app.kubernetes.io/component: controller
    app.kubernetes.io/instance: juicefs-csi-driver
    app.kubernetes.io/name: juicefs-csi-driver
    app.kubernetes.io/version: master
  name: juicefs-csi-controller
  namespace: kube-system
spec:
  replicas: 2
  selector:
    matchLabels:
      app: juicefs-csi-controller
      app.kubernetes.io/instance: juicefs-csi-driver
      app.kubernetes.io/name: juicefs-csi-driver
      app.kubernetes.io/version: master
  serviceName: juicefs-csi-controller
  template:
    metadata:
      labels:
        app: juicefs-csi-controller
        app.kubernetes.io/instance: juicefs-csi-driver
        app.kubernetes.io/name: juicefs-csi-driver
        app.kubernetes.io/version: master
    spec:
      containers:
      - args:
        - --endpoint=$(CSI_ENDPOINT)
        - --logtostderr
        - --nodeid=$(NODE_NAME)
        - --leader-election
        - --v=5
        - --webhook=true
        - --validating-webhook=true
        env:
        - name: CSI_ENDPOINT
          value: unix:///var/lib/csi/sockets/pluginproxy/csi.sock
        - name: NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        - name: JUICEFS_MOUNT_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: JUICEFS_MOUNT_PATH
          value: /var/lib/juicefs/volume
        - name: JUICEFS_CONFIG_PATH
          value: /var/lib/juicefs/config
        image: juicedata/juicefs-csi-driver:v0.23.5
        livenessProbe:
          failureThreshold: 5
          httpGet:
            path: /healthz
            port: healthz
          initialDelaySeconds: 10
          periodSeconds: 10
          timeoutSeconds: 3
        name: juicefs-plugin
        ports:
        - containerPort: 9909
          name: healthz
          protocol: TCP
        resources:
          limits:
            cpu: 1000m
            memory: 1Gi
          requests:
            cpu: 100m
            memory: 512Mi
        securityContext:
          capabilities:
            add:
            - SYS_ADMIN
          privileged: true
        volumeMounts:
        - mountPath: /var/lib/csi/sockets/pluginproxy/
          name: socket-dir
        - mountPath: /jfs
          mountPropagation: Bidirectional
          name: jfs-dir
        - mountPath: /root/.juicefs
          mountPropagation: Bidirectional
          name: jfs-root-dir
        - mountPath: /etc/webhook/certs
          name: webhook-certs
          readOnly: true
      - args:
        - --csi-address=$(ADDRESS)
        - --timeout=60s
        - --leader-election
        - --v=5
        env:
        - name: ADDRESS
          value: /var/lib/csi/sockets/pluginproxy/csi.sock
        image: registry.k8s.io/sig-storage/csi-provisioner:v2.2.2
        name: csi-provisioner
        volumeMounts:
        - mountPath: /var/lib/csi/sockets/pluginproxy/
          name: socket-dir
      - args:
        - --csi-address=$(ADDRESS)
        - --leader-election
        - --v=2
        env:
        - name: ADDRESS
          value: /var/lib/csi/sockets/pluginproxy/csi.sock
        image: registry.k8s.io/sig-storage/csi-resizer:v1.9.0
        name: csi-resizer
        volumeMounts:
        - mountPath: /var/lib/csi/sockets/pluginproxy/
          name: socket-dir
      - args:
        - --csi-address=$(ADDRESS)
        - --health-port=$(HEALTH_PORT)
        env:
        - name: ADDRESS
          value: /csi/csi.sock
        - name: HEALTH_PORT
          value: "9909"
        image: registry.k8s.io/sig-storage/livenessprobe:v2.11.0
        name: liveness-probe
        volumeMounts:
        - mountPath: /csi
          name: socket-dir
      priorityClassName: system-cluster-critical
      serviceAccount: juicefs-csi-controller-sa
      tolerations:
      - key: CriticalAddonsOnly
        operator: Exists
      volumes:
      - emptyDir: {}
        name: socket-dir
      - hostPath:
          path: /var/lib/juicefs/volume
          type: DirectoryOrCreate
        name: jfs-dir
      - hostPath:
          path: /var/lib/juicefs/config
          type: DirectoryOrCreate
        name: jfs-root-dir
      - name: webhook-certs
        secret:
          secretName: juicefs-webhook-certs
  volumeClaimTemplates: []
---
apiVersion: storage.k8s.io/v1
kind: CSIDriver
metadata:
  labels:
    app.kubernetes.io/instance: juicefs-csi-driver
    app.kubernetes.io/name: juicefs-csi-driver
    app.kubernetes.io/version: master
  name: csi.juicefs.com
spec:
  attachRequired: false
  podInfoOnMount: true
---
apiVersion: admissionregistration.k8s.io/v1
kind: MutatingWebhookConfiguration
metadata:
  labels:
    app.kubernetes.io/instance: juicefs-csi-driver
    app.kubernetes.io/name: juicefs-csi-driver
    app.kubernetes.io/version: master
  name: juicefs-admission-serverless-webhook
webhooks:
- admissionReviewVersions:
  - v1
  - v1beta1
  clientConfig:
    caBundle: CA_BUNDLE
    service:
      name: juicefs-admission-webhook
      namespace: kube-system
      path: /juicefs/serverless/inject-v1-pod
  failurePolicy: Fail
  name: sidecar.inject.serverless.juicefs.com
  namespaceSelector:
    matchLabels:
      juicefs.com/enable-serverless-injection: "true"
  rules:
  - apiGroups:
    - ""
    apiVersions:
    - v1
    operations:
    - CREATE
    resources:
    - pods
  sideEffects: None
  timeoutSeconds: 20
---
apiVersion: admissionregistration.k8s.io/v1
kind: MutatingWebhookConfiguration
metadata:
  labels:
    app.kubernetes.io/instance: juicefs-csi-driver
    app.kubernetes.io/name: juicefs-csi-driver
    app.kubernetes.io/version: master
  name: juicefs-admission-webhook
webhooks:
- admissionReviewVersions:
  - v1
  - v1beta1
  clientConfig:
    caBundle: CA_BUNDLE
    service:
      name: juicefs-admission-webhook
      namespace: kube-system
      path: /juicefs/inject-v1-pod
  failurePolicy: Fail
  name: sidecar.inject.juicefs.com
  namespaceSelector:
    matchLabels:
      juicefs.com/enable-injection: "true"
  rules:
  - apiGroups:
    - ""
    apiVersions:
    - v1
    operations:
    - CREATE
    resources:
    - pods
  sideEffects: None
  timeoutSeconds: 20
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingWebhookConfiguration
metadata:
  labels:
    app.kubernetes.io/instance: juicefs-csi-driver
    app.kubernetes.io/name: juicefs-csi-driver
    app.kubernetes.io/version: master
  name: juicefs-admission-webhook
webhooks:
- admissionReviewVersions:
  - v1
  clientConfig:
    caBundle: CA_BUNDLE
    service:
      name: juicefs-admission-webhook
      namespace: kube-system
      path: /juicefs/validate-secret
  failurePolicy: Ignore
  matchPolicy: Equivalent
  name: validate.secret.juicefs.com
  objectSelector:
    matchLabels:
      juicefs.com/validate-secret: "true"
  rules:
  - apiGroups:
    - ""
    apiVersions:
    - v1
    operations:
    - CREATE
    - UPDATE
    resources:
    - secrets
  sideEffects: None
  timeoutSeconds: 5
EOF
  # webhook.yaml end

  cat ${tmpdir}/webhook.yaml | sed -e "s/CA_BUNDLE/$CA_BUNDLE/g" -e "s/TLS_KEY/$TLS_KEY/g" -e "s/TLS_CRT/$TLS_CRT/g"
}

function gen_webhook_manifests_with_cert_manager() {
  tmpdir=$(mktemp -d)
  # webhook-with-certmanager.yaml start
  cat <<\EOF >${tmpdir}/webhook-with-certmanager.yaml
# DO NOT EDIT: generated by 'kustomize build'
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    app.kubernetes.io/instance: juicefs-csi-driver
    app.kubernetes.io/name: juicefs-csi-driver
    app.kubernetes.io/version: master
  name: juicefs-csi-controller-sa
  namespace: kube-system
---
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    app.kubernetes.io/instance: juicefs-csi-driver
    app.kubernetes.io/name: juicefs-csi-driver
    app.kubernetes.io/version: master
  name: juicefs-csi-dashboard-sa
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  labels:
    app.kubernetes.io/instance: juicefs-csi-driver
    app.kubernetes.io/name: juicefs-csi-driver
    app.kubernetes.io/version: master
  name: juicefs-csi-dashboard-role
rules:
- apiGroups:
  - ""
  resources:
  - pods
  - persistentvolumes
  - persistentvolumeclaims
  - persistentvolumeclaims/status
  - nodes
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - storage.k8s.io
  resources:
  - storageclasses
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - ""
  resources:
  - events
  verbs:
  - get
  - list
  - watch
  - create
  - update
  - patch
- apiGroups:
  - ""
  resources:
  - pods/log
  verbs:
  - get
- apiGroups:
  - batch
  resources:
  - jobs
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - ""
  resources:
  - nodes/proxy
  verbs:
  - '*'
- apiGroups:
  - ""
  resources:
  - persistentvolumes
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - coordination.k8s.io
  resources:
  - leases
  verbs:
  - get
  - watch
  - list
  - delete
  - update
  - create
- apiGroups:
  - ""
  resources:
  - configmaps
  verbs:
  - get
  - watch
  - list
  - delete
  - update
  - create
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  labels:
    app.kubernetes.io/instance: juicefs-csi-driver
    app.kubernetes.io/name: juicefs-csi-driver
    app.kubernetes.io/version: master
  name: juicefs-external-provisioner-role
rules:
- apiGroups:
  - ""
  resources:
  - persistentvolumes
  verbs:
  - get
  - list
  - watch
  - create
  - delete
  - patch
- apiGroups:
  - ""
  resources:
  - persistentvolumeclaims
  - persistentvolumeclaims/status
  verbs:
  - get
  - list
  - watch
  - update
  - patch
- apiGroups:
  - storage.k8s.io
  resources:
  - storageclasses
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - ""
  resources:
  - events
  verbs:
  - list
  - watch
  - create
  - update
  - patch
- apiGroups:
  - storage.k8s.io
  resources:
  - csinodes
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - ""
  resources:
  - nodes
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - ""
  resources:
  - secrets
  verbs:
  - get
  - list
  - watch
  - create
  - update
  - patch
  - delete
- apiGroups:
  - ""
  resources:
  - pods
  - pods/log
  verbs:
  - get
  - list
  - watch
  - create
  - update
  - patch
  - delete
- apiGroups:
  - batch
  resources:
  - jobs
  verbs:
  - get
  - create
  - update
  - patch
  - delete
  - list
  - watch
- apiGroups:
  - ""
  resources:
  - endpoints
  verbs:
  - get
  - list
  - watch
  - create
  - update
  - patch
- apiGroups:
  - apps
  resources:
  - daemonsets
  verbs:
  - get
  - list
- apiGroups:
  - coordination.k8s.io
  resources:
  - leases
  verbs:
  - get
  - watch
  - list
  - delete
  - update
  - create
- apiGroups:
  - ""
  resources:
  - configmaps
  verbs:
  - get
  - watch
  - list
  - delete
  - update
  - create
- apiGroups:
  - ""
  resources:
  - pods/exec
  verbs:
  - '*'
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  labels:
    app.kubernetes.io/instance: juicefs-csi-driver
    app.kubernetes.io/name: juicefs-csi-driver
    app.kubernetes.io/version: master
  name: juicefs-csi-dashboard-rolebinding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: juicefs-csi-dashboard-role
subjects:
- kind: ServiceAccount
  name: juicefs-csi-dashboard-sa
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  labels:
    app.kubernetes.io/instance: juicefs-csi-driver
    app.kubernetes.io/name: juicefs-csi-driver
    app.kubernetes.io/version: master
  name: juicefs-csi-provisioner-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: juicefs-external-provisioner-role
subjects:
- kind: ServiceAccount
  name: juicefs-csi-controller-sa
  namespace: kube-system
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app.kubernetes.io/instance: juicefs-csi-driver
    app.kubernetes.io/name: juicefs-csi-driver
    app.kubernetes.io/version: master
  name: juicefs-admission-webhook
  namespace: kube-system
spec:
  ports:
  - name: https-rest
    port: 443
    targetPort: 9444
  selector:
    app: juicefs-csi-controller
    app.kubernetes.io/instance: juicefs-csi-driver
    app.kubernetes.io/name: juicefs-csi-driver
    app.kubernetes.io/version: master
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app.kubernetes.io/component: dashboard
    app.kubernetes.io/instance: juicefs-csi-driver
    app.kubernetes.io/name: juicefs-csi-driver
    app.kubernetes.io/version: master
  name: juicefs-csi-dashboard
  namespace: kube-system
spec:
  ports:
  - name: http
    port: 8088
    protocol: TCP
    targetPort: 8088
  selector:
    app: juicefs-csi-dashboard
    app.kubernetes.io/instance: juicefs-csi-driver
    app.kubernetes.io/name: juicefs-csi-driver
    app.kubernetes.io/version: master
  type: ClusterIP
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app.kubernetes.io/component: dashboard
    app.kubernetes.io/instance: juicefs-csi-driver
    app.kubernetes.io/name: juicefs-csi-driver
    app.kubernetes.io/version: master
  name: juicefs-csi-dashboard
  namespace: kube-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: juicefs-csi-dashboard
      app.kubernetes.io/instance: juicefs-csi-driver
      app.kubernetes.io/name: juicefs-csi-driver
      app.kubernetes.io/version: master
  template:
    metadata:
      labels:
        app: juicefs-csi-dashboard
        app.kubernetes.io/instance: juicefs-csi-driver
        app.kubernetes.io/name: juicefs-csi-driver
        app.kubernetes.io/version: master
    spec:
      containers:
      - args:
        - --static-dir=/dist
        env:
        - name: SYS_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        image: juicedata/csi-dashboard:v0.23.5
        name: dashboard
        ports:
        - containerPort: 8088
        resources:
          limits:
            cpu: 1000m
            memory: 1Gi
          requests:
            cpu: 100m
            memory: 200Mi
      serviceAccountName: juicefs-csi-dashboard-sa
      tolerations:
      - key: CriticalAddonsOnly
        operator: Exists
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  labels:
    app.kubernetes.io/component: controller
    app.kubernetes.io/instance: juicefs-csi-driver
    app.kubernetes.io/name: juicefs-csi-driver
    app.kubernetes.io/version: master
  name: juicefs-csi-controller
  namespace: kube-system
spec:
  replicas: 2
  selector:
    matchLabels:
      app: juicefs-csi-controller
      app.kubernetes.io/instance: juicefs-csi-driver
      app.kubernetes.io/name: juicefs-csi-driver
      app.kubernetes.io/version: master
  serviceName: juicefs-csi-controller
  template:
    metadata:
      labels:
        app: juicefs-csi-controller
        app.kubernetes.io/instance: juicefs-csi-driver
        app.kubernetes.io/name: juicefs-csi-driver
        app.kubernetes.io/version: master
    spec:
      containers:
      - args:
        - --endpoint=$(CSI_ENDPOINT)
        - --logtostderr
        - --nodeid=$(NODE_NAME)
        - --leader-election
        - --v=5
        - --webhook=true
        - --validating-webhook=true
        env:
        - name: CSI_ENDPOINT
          value: unix:///var/lib/csi/sockets/pluginproxy/csi.sock
        - name: NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        - name: JUICEFS_MOUNT_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: JUICEFS_MOUNT_PATH
          value: /var/lib/juicefs/volume
        - name: JUICEFS_CONFIG_PATH
          value: /var/lib/juicefs/config
        image: juicedata/juicefs-csi-driver:v0.23.5
        livenessProbe:
          failureThreshold: 5
          httpGet:
            path: /healthz
            port: healthz
          initialDelaySeconds: 10
          periodSeconds: 10
          timeoutSeconds: 3
        name: juicefs-plugin
        ports:
        - containerPort: 9909
          name: healthz
          protocol: TCP
        resources:
          limits:
            cpu: 1000m
            memory: 1Gi
          requests:
            cpu: 100m
            memory: 512Mi
        securityContext:
          capabilities:
            add:
            - SYS_ADMIN
          privileged: true
        volumeMounts:
        - mountPath: /var/lib/csi/sockets/pluginproxy/
          name: socket-dir
        - mountPath: /jfs
          mountPropagation: Bidirectional
          name: jfs-dir
        - mountPath: /root/.juicefs
          mountPropagation: Bidirectional
          name: jfs-root-dir
        - mountPath: /etc/webhook/certs
          name: webhook-certs
          readOnly: true
      - args:
        - --csi-address=$(ADDRESS)
        - --timeout=60s
        - --leader-election
        - --v=5
        env:
        - name: ADDRESS
          value: /var/lib/csi/sockets/pluginproxy/csi.sock
        image: registry.k8s.io/sig-storage/csi-provisioner:v2.2.2
        name: csi-provisioner
        volumeMounts:
        - mountPath: /var/lib/csi/sockets/pluginproxy/
          name: socket-dir
      - args:
        - --csi-address=$(ADDRESS)
        - --leader-election
        - --v=2
        env:
        - name: ADDRESS
          value: /var/lib/csi/sockets/pluginproxy/csi.sock
        image: registry.k8s.io/sig-storage/csi-resizer:v1.9.0
        name: csi-resizer
        volumeMounts:
        - mountPath: /var/lib/csi/sockets/pluginproxy/
          name: socket-dir
      - args:
        - --csi-address=$(ADDRESS)
        - --health-port=$(HEALTH_PORT)
        env:
        - name: ADDRESS
          value: /csi/csi.sock
        - name: HEALTH_PORT
          value: "9909"
        image: registry.k8s.io/sig-storage/livenessprobe:v2.11.0
        name: liveness-probe
        volumeMounts:
        - mountPath: /csi
          name: socket-dir
      priorityClassName: system-cluster-critical
      serviceAccount: juicefs-csi-controller-sa
      tolerations:
      - key: CriticalAddonsOnly
        operator: Exists
      volumes:
      - emptyDir: {}
        name: socket-dir
      - hostPath:
          path: /var/lib/juicefs/volume
          type: DirectoryOrCreate
        name: jfs-dir
      - hostPath:
          path: /var/lib/juicefs/config
          type: DirectoryOrCreate
        name: jfs-root-dir
      - name: webhook-certs
        secret:
          secretName: juicefs-webhook-certs
  volumeClaimTemplates: []
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: juicefs-cert
  namespace: kube-system
spec:
  dnsNames:
  - juicefs-admission-webhook
  - juicefs-admission-webhook.kube-system
  - juicefs-admission-webhook.kube-system.svc
  duration: 43800h
  issuerRef:
    name: juicefs-selfsigned
  secretName: juicefs-webhook-certs
---
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: juicefs-selfsigned
  namespace: kube-system
spec:
  selfSigned: {}
---
apiVersion: storage.k8s.io/v1
kind: CSIDriver
metadata:
  labels:
    app.kubernetes.io/instance: juicefs-csi-driver
    app.kubernetes.io/name: juicefs-csi-driver
    app.kubernetes.io/version: master
  name: csi.juicefs.com
spec:
  attachRequired: false
  podInfoOnMount: true
---
apiVersion: admissionregistration.k8s.io/v1
kind: MutatingWebhookConfiguration
metadata:
  labels:
    app.kubernetes.io/instance: juicefs-csi-driver
    app.kubernetes.io/name: juicefs-csi-driver
    app.kubernetes.io/version: master
  name: juicefs-admission-serverless-webhook
webhooks:
- admissionReviewVersions:
  - v1
  - v1beta1
  clientConfig:
    caBundle: CA_BUNDLE
    service:
      name: juicefs-admission-webhook
      namespace: kube-system
      path: /juicefs/serverless/inject-v1-pod
  failurePolicy: Fail
  name: sidecar.inject.serverless.juicefs.com
  namespaceSelector:
    matchLabels:
      juicefs.com/enable-serverless-injection: "true"
  rules:
  - apiGroups:
    - ""
    apiVersions:
    - v1
    operations:
    - CREATE
    resources:
    - pods
  sideEffects: None
  timeoutSeconds: 20
---
apiVersion: admissionregistration.k8s.io/v1
kind: MutatingWebhookConfiguration
metadata:
  annotations:
    cert-manager.io/inject-ca-from: kube-system/juicefs-cert
  labels:
    app.kubernetes.io/instance: juicefs-csi-driver
    app.kubernetes.io/name: juicefs-csi-driver
    app.kubernetes.io/version: master
  name: juicefs-admission-webhook
webhooks:
- admissionReviewVersions:
  - v1
  - v1beta1
  clientConfig:
    caBundle: CA_BUNDLE
    service:
      name: juicefs-admission-webhook
      namespace: kube-system
      path: /juicefs/inject-v1-pod
  failurePolicy: Fail
  name: sidecar.inject.juicefs.com
  namespaceSelector:
    matchLabels:
      juicefs.com/enable-injection: "true"
  rules:
  - apiGroups:
    - ""
    apiVersions:
    - v1
    operations:
    - CREATE
    resources:
    - pods
  sideEffects: None
  timeoutSeconds: 20
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingWebhookConfiguration
metadata:
  annotations:
    cert-manager.io/inject-ca-from: kube-system/juicefs-cert
  labels:
    app.kubernetes.io/instance: juicefs-csi-driver
    app.kubernetes.io/name: juicefs-csi-driver
    app.kubernetes.io/version: master
  name: juicefs-admission-webhook
webhooks:
- admissionReviewVersions:
  - v1
  clientConfig:
    caBundle: CA_BUNDLE
    service:
      name: juicefs-admission-webhook
      namespace: kube-system
      path: /juicefs/validate-secret
  failurePolicy: Ignore
  matchPolicy: Equivalent
  name: validate.secret.juicefs.com
  objectSelector:
    matchLabels:
      juicefs.com/validate-secret: "true"
  rules:
  - apiGroups:
    - ""
    apiVersions:
    - v1
    operations:
    - CREATE
    - UPDATE
    resources:
    - secrets
  sideEffects: None
  timeoutSeconds: 5
EOF
  # webhook-with-certmanager.yaml end

  cat ${tmpdir}/webhook-with-certmanager.yaml | sed -e "s/CA_BUNDLE/Cg==/g"
}

need_cmd() {
  if ! check_cmd "$1"; then
    err "need '$1' (command not found)"
  fi
}

check_cmd() {
  command -v "$1" >/dev/null 2>&1
}

ensure() {
  if ! "$@"; then err "command failed: $*"; fi
}

function main() {
  if [[ $# -eq 0 ]]; then
    print_usage
    exit 1
  fi

  action="help"
  withcertmanager="false"

  while [[ $# -gt 0 ]]; do
    case $1 in
    -h | --help | "-?")
      print_usage
      exit 0
      ;;
    install | help)
      action=$1
      ;;
    print | help)
      action=$1
      ;;
    -c|--with-certmanager)
      withcertmanager="true"
      ;;
    *)
      echo "Error: unsupported option $1" >&2
      print_usage
      exit 1
      ;;
    esac
    shift
  done

  if [[ ${withcertmanager} == "true" ]]
  then
    case ${action} in
    install)
      gen_webhook_manifests_with_cert_manager | kubectl apply -f -
      ;;
    print)
      gen_webhook_manifests_with_cert_manager | cat
      ;;
    help)
      print_usage
      ;;
    esac
  else
    case ${action} in
    install)
      gen_webhook_manifests | kubectl apply -f -
      ;;
    print)
      gen_webhook_manifests | cat
      ;;
    help)
      print_usage
      ;;
    esac
  fi
}

main "$@"
