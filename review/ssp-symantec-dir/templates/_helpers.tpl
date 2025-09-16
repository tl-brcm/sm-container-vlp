{{/*
Expand the name of the chart.
*/}}
{{- define "name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Base64 Encode Registry Credentials
*/}}
{{- define "imagePullSecret" -}}
{{- $registryUrl := default "docker.io" .Values.global.registry.url -}}
{{- printf "{\"auths\": {\"%s\": {\"auth\": \"%s\"}}}" $registryUrl (printf "%s:%s" .Values.global.registry.credentials.username .Values.global.registry.credentials.password | b64enc) | b64enc -}}
{{- end -}}

{{/*
Creates the image path. If useImageDigest is set to true, and image digest is available, use it.
Otherwise, check if image tag is available,  if available, use it.
if tag is not specified, use the Chart's AppVersion as the image tag.
Expects: dict "root" . "component" "XXXX"
where XXX is the name of the component (as it appears in values.yaml) whose image path should be generated.
i.e.
       image: {{ template "image" dict "root" . "component" "symantec_dir" }}
*/}}
{{- define "image" -}}
{{- $root := .root -}}
{{- $component := .component -}}
{{- $imageRepository := index $root "Values" "image" $component "repository" -}}
{{- $imageRepositoryBase := $root.Values.global.registry.imageRepositoryBase |trimSuffix "/" -}}
{{- $imageName := index $root "Values" "image" $component "name" -}}

{{- if and (not $imageRepository) $imageRepositoryBase -}}
{{- $imageRepository =  printf "%s/%s"  ($imageRepositoryBase)  ($imageName) -}}
{{- end -}}
{{- if not ( $imageRepository ) -}}
   {{ required (printf "Missing image info for %s (imageBase: %s, imageName: %s)" $component $imageRepositoryBase $imageName ) $root.randomValueThatDoesNotExist -}}
{{- end -}}

{{- $image := $imageRepository -}}
{{- $imageTag := index $root "Values" "image" $component "tag" -}}

{{- if $imageTag -}}
{{- $image = printf "%s:%s"  $imageRepository $imageTag  -}}
{{- end -}}

{{- $imageDigest := index $root "Values" "image" $component "digest" -}}
{{- if and (index $root "Values" "global" "useImageDigest") $imageDigest -}}
{{- printf "%s@%s"  $image $imageDigest | quote -}}
{{- else -}}
{{- $image | quote -}}
{{- end -}}
{{- end -}}

{{- define "tls.secretName.def" -}}
{{- $secretname := printf "%s-tls" (include "fullname" .) -}}
{{- $secretname }}
{{- end -}}

{{- define "tls.secretName" -}}
{{ default (include "tls.secretName.def" .)  .Values.dsaConfig.tls.existingSecretName }}
{{- end -}}


