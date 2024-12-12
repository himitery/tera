{{/* Templates for certificates injection */}}

{{- define "gitlab.certificates.initContainer" -}}
{{- $customCAsEnabled := .Values.global.certificates.customCAs }}
{{- $internalGitalyTLSEnabled := $.Values.global.gitaly.tls.enabled }}
{{- $internalPraefectTLSEnabled := $.Values.global.praefect.tls.enabled }}
{{- $imageCfg := dict "global" .Values.global.image "local" .Values.global.certificates.image -}}
- name: certificates
  image: {{ include "gitlab.certificates.image" . }}
  {{- include "gitlab.image.pullPolicy" $imageCfg | indent 2 }}
  {{- include "gitlab.init.containerSecurityContext" . | indent 2 }}
  env:
  {{- include "gitlab.extraEnv" . | nindent 2 }}
  {{- include "gitlab.extraEnvFrom" (dict "root" $ "local" .) | nindent 2 }}
  volumeMounts:
  - name: etc-ssl-certs
    mountPath: /etc/ssl/certs
    readOnly: false
  - name: etc-pki-ca-trust-extracted-pem
    mountPath: /etc/pki/ca-trust/extracted/pem
    readOnly: false
  resources:
    {{- toYaml .Values.init.resources | nindent 4 }}
{{- end -}}

{{- define "gitlab.certificates.volumes" -}}
{{- $customCAsEnabled := .Values.global.certificates.customCAs }}
{{- $internalGitalyTLSEnabled := $.Values.global.gitaly.tls.enabled }}
{{- $internalPraefectTLSEnabled := $.Values.global.praefect.tls.enabled }}
- name: etc-ssl-certs
  emptyDir:
    medium: "Memory"
- name: etc-pki-ca-trust-extracted-pem
  emptyDir:
    medium: "Memory"
{{- end -}}

{{- define "gitlab.certificates.volumeMount" -}}
- name: etc-ssl-certs
  mountPath: /etc/ssl/certs/
  readOnly: true
- name: etc-pki-ca-trust-extracted-pem
  mountPath: /etc/pki/ca-trust/extracted/pem
  readOnly: true
{{- end -}}
