# dependencies
FROM docker.io/fluxcd/flux-cli:v0.17.2 as flux
FROM docker.io/hadolint/hadolint:v2.7.0 as hadolint
FROM docker.io/alpine/helm:3.6.3 as helm
FROM docker.io/jnorwood/helm-docs:v1.5.0 as helm-docs
# FROM docker.io/zegl/kube-score:v1.12.0 as kube-score
FROM docker.io/bitnami/kubectl:1.20.9 as kubectl
FROM docker.io/cytopia/kubeval:0.16 as kubeval
# FROM docker.io/kubesec/kubesec:v2.11.4 as kubesec
FROM k8s.gcr.io/kustomize/kustomize:v4.3.0 as kustomize
FROM docker.io/koalaman/shellcheck:v0.7.2 as shellcheck
# FROM docker.io/aquasec/trivy:0.19.2 as trivy
FROM docker.io/mikefarah/yq:4.13.0 as yq
FROM docker.io/prom/prometheus:v2.30.0 as prom
FROM docker.io/prom/alertmanager:v0.23.0 as prom-am

# base image
FROM ubuntu:focal-20210921

WORKDIR /opt/toolbox

ENV \
  GOPATH="/opt/toolbox/go" \
  PATH="$PATH:/opt/toolbox/node_modules/.bin:/opt/toolbox/go/bin"

RUN \
  apt-get update \
  && apt-get install --no-install-recommends -qy
    ca-certificates \
    curl \
    git \
    jq \
    unzip

# aws-cli \
# go \
# gnupg \
# nodejs \
# npm \
# py3-pip \
# python3 \
# shfmt \
# terraform \

# WORKDIR /tmp/trivy
# # trivy contrib files.
# RUN \
#   git clone https://github.com/aquasecurity/trivy.git --branch v0.19.2 --depth 1 --single-branch . \
#   && mkdir -p /opt/toolbox/trivy/contrib/ \
#   && cp /tmp/trivy/contrib/*.tpl /opt/toolbox/trivy/contrib/ \
#   && rm -rf /tmp/trivy

WORKDIR /opt/toolbox

# golang
RUN \
  go install github.com/drone/envsubst/cmd/envsubst@latest \
  && envsubst --version

# # nodejs
# COPY package*.json .
# RUN \
#   npm ci --only=production \
#   && markdownlint --version \
#   && prettier --version \
#   && semantic-release --version

# # python
# COPY scripts/* /opt/toolbox/custom-scripts/
# COPY requirements.txt .
# RUN \
#   pip install --no-cache-dir -r requirements.txt && \
#   yamllint --version \
#   && find /usr/lib/ -name '__pycache__' -print0 | xargs -0 -n1 rm -rf \
#   && find /usr/lib/ -name '*.pyc' -print0 | xargs -0 -n1 rm -rf

RUN \
  sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d -b /usr/local/bin \
  && task --version

# RUN \
#   sops_version=$(curl -sL "https://api.github.com/repos/mozilla/sops/releases/latest" | jq --raw-output ".tag_name") \
#   && curl -fsSL -o "/usr/local/bin/sops" \
#   "https://github.com/mozilla/sops/releases/download/${sops_version}/sops-${sops_version}.linux"\
#   && chmod +x "/usr/local/bin/sops" \
#   && sops --version

COPY --from=flux /usr/local/bin/flux /usr/local/bin/flux
RUN flux --version

COPY --from=hadolint /bin/hadolint /usr/local/bin/hadolint
RUN hadolint --version

COPY --from=helm /usr/bin/helm /usr/local/bin/helm
RUN helm version

COPY --from=helm-docs /usr/bin/helm-docs /usr/local/bin/helm-docs
RUN helm-docs --version

# COPY --from=kube-score /kube-score /usr/local/bin/kube-score
# RUN kube-score version

COPY --from=kubectl /opt/bitnami/kubectl/bin/kubectl /usr/local/bin/kubectl
RUN kubectl version --client

COPY --from=kubeval /usr/bin/kubeval /usr/local/bin/kubeval
RUN kubeval --version

# COPY --from=kubesec /kubesec /usr/local/bin/kubesec
# RUN kubesec version

COPY --from=kustomize /app/kustomize /usr/local/bin/kustomize
RUN kustomize version

COPY --from=shellcheck /bin/shellcheck /usr/local/bin/shellcheck
RUN shellcheck --version

# COPY --from=trivy /usr/local/bin/trivy /usr/local/bin/trivy
# RUN trivy --version

COPY --from=yq /usr/bin/yq /usr/local/bin/yq
RUN yq --version

COPY --from=prom /bin/promtool /usr/local/bin/promtool
RUN promtool --version

COPY --from=prom-am /bin/amtool /usr/local/bin/amtool
RUN amtool --version

CMD /bin/fish
