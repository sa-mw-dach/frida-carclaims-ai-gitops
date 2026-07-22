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