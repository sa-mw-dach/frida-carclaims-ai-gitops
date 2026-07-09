{{- define "frida-carclaims.namespace" -}}
{{- .Values.global.namespace -}}
{{- end -}}

{{- define "frida-carclaims.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "frida-carclaims.labels" -}}
app.kubernetes.io/part-of: {{ .Values.global.partOf }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ include "frida-carclaims.chart" . }}
{{- end -}}

{{- define "frida-carclaims.frontend.image" -}}
{{- printf "%s:%s" .Values.frontend.image.repository .Values.frontend.image.tag -}}
{{- end -}}

{{- define "frida-carclaims.backend.image" -}}
{{- printf "%s:%s" .Values.backend.image.repository .Values.backend.image.tag -}}
{{- end -}}

{{- define "frida-carclaims.route.host" -}}
{{- if .Values.frontend.route.host -}}
{{- .Values.frontend.route.host -}}
{{- else -}}
{{- $env := required "global.environment is required (dev, stage, or prod)" .Values.global.environment -}}
{{- $domain := required "global.appsDomain is required (e.g. apps.mycluster.example.com)" .Values.global.appsDomain -}}
{{- if eq $env "prod" -}}
frida-carclaims.{{ $domain }}
{{- else -}}
frida-carclaims-{{ $env }}.{{ $domain }}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "frida-carclaims.publicUrl" -}}
https://{{ include "frida-carclaims.route.host" . }}/
{{- end -}}
