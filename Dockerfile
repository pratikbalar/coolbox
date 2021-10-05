# dependencies
FROM docker.io/fluxcd/flux-cli:v0.17.2 as flux
FROM docker.io/hadolint/hadolint:v2.7.0 as hadolint
FROM docker.io/alpine/helm:3.6.3 as helm
FROM docker.io/jnorwood/helm-docs:v1.5.0 as helm-docs
FROM docker.io/zegl/kube-score:v1.12.0 as kube-score
FROM docker.io/bitnami/kubectl:1.20.9 as kubectl
FROM docker.io/cytopia/kubeval:0.16 as kubeval
FROM docker.io/kubesec/kubesec:v2.11.4 as kubesec
FROM k8s.gcr.io/kustomize/kustomize:v4.3.0 as kustomize
FROM docker.io/koalaman/shellcheck:v0.7.2 as shellcheck
FROM docker.io/hashicorp/terraform:1.0.8 as terraform
FROM docker.io/aquasec/trivy:0.19.2 as trivy
FROM docker.io/mikefarah/yq:4.13.0 as yq
FROM docker.io/prom/prometheus:v2.30.3 as prom
FROM docker.io/prom/alertmanager:v0.23.0 as prom-am

# base image
FROM ubuntu:focal-20210921

WORKDIR /opt/toolbox

# DEBIAN_FRONTEND: https://askubuntu.com/questions/972516/debian-frontend-environment-variable
# APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE: http://stackoverflow.com/questions/48162574/ddg#49462622
ENV \
  DEBCONF_NONINTERACTIVE_SEEN=true \
  DEBIAN_FRONTEND="noninteractive" \
  APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=DontWarn

ENV \
  GO_VERSION=1.17

ENV \
  GOPATH="/opt/toolbox/go" \
  PATH="$PATH:/opt/toolbox/node_modules/.bin:/usr/lib/go-${GO_VERSION}/bin:/opt/toolbox/go/bin"

# hadolint ignore=DL3008,DL3015
RUN \
  set -eux \
  && echo 'APT::Install-Recommends "false";' >/etc/apt/apt.conf.d/00recommends \
  && echo 'APT::Install-Suggests "false";' >>/etc/apt/apt.conf.d/00recommends \
  && echo 'APT::Get::Install-Recommends "false";' >>/etc/apt/apt.conf.d/00recommends \
  && echo 'APT::Get::Install-Suggests "false";' >>/etc/apt/apt.conf.d/00recommends \
  && \
  apt-get update -qy \
  && apt-get install -qy \
    apt-transport-https \
    bash \
    ca-certificates \
    curl \
    git \
    gnupg \
    jq \
    lsb-release \
    python3 \
    python3-dev \
    python3-pip \
    software-properties-common \
    tmux \
    # shfmt \
    unzip \
  && \
  apt-get purge -qy --auto-remove -o APT::AutoRemove::RecommendsImportant=false && \
  apt-get autoremove -qy && \
  apt-get clean -qy && \
  rm -rf \
    /tmp/* \
    /var/lib/apt/lists/* \
    /var/cache/apt/* \
    /var/tmp/*

# install fish shell
# hadolint ignore=DL3008,DL3015,DL4006
RUN \
  add-apt-repository ppa:fish-shell/release-3 \
  && \
  apt-get update -qy && \
  apt-get install -qy \
    fish \
  && \
  apt-get purge -qy --auto-remove -o APT::AutoRemove::RecommendsImportant=false && \
  apt-get autoremove -qy && \
  apt-get clean -qy && \
  rm -rf \
    /tmp/* \
    /var/lib/apt/lists/* \
    /var/cache/apt/* \
    /var/tmp/*

# install nodejs
# hadolint ignore=DL3008,DL3015,DL4006
RUN \
  curl -sL https://deb.nodesource.com/setup_14.x | bash - && \
  apt-get update -qy && \
  apt-get install -qy \
    gcc \
    g++ \
    make \
    nodejs \
  && \
  apt-get purge -qy --auto-remove -o APT::AutoRemove::RecommendsImportant=false && \
  apt-get autoremove -qy && \
  apt-get clean -qy && \
  rm -rf \
    /tmp/* \
    /var/lib/apt/lists/* \
    /var/cache/apt/* \
    /var/tmp/*

# install golang
# hadolint ignore=DL3008,DL3015,DL4006
RUN \
  add-apt-repository ppa:longsleep/golang-backports \
  && \
  apt-get update -qy && \
  apt-get install -qy \
    golang-${GO_VERSION} \
  && \
  apt-get purge -qy --auto-remove -o APT::AutoRemove::RecommendsImportant=false && \
  apt-get autoremove -qy && \
  apt-get clean -qy && \
  rm -rf \
    /tmp/* \
    /var/lib/apt/lists/* \
    /var/cache/apt/* \
    /var/tmp/*

# WORKDIR /tmp/trivy
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

# python
COPY requirements.txt .
RUN \
  pip install --no-cache-dir -r requirements.txt \
  && \
  aws --version \
  && yamllint --version \
  && find /usr/lib/ -name '__pycache__' -print0 | xargs -0 -n1 rm -rf \
  && find /usr/lib/ -name '*.pyc' -print0 | xargs -0 -n1 rm -rf

RUN \
  sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d -b /usr/local/bin \
  && task --version

# renovate: datasource=github-releases depName=sbstp/kubie
ENV KUBIE_VERSION=v0.15.0
RUN \
  curl -fsSL -o "/usr/local/bin/kubie" \
    "https://github.com/sbstp/kubie/releases/download/${KUBIE_VERSION}/kubie-linux-amd64" \
  && chmod +x /usr/local/bin/kubie \
  && kubie --version

# renovate: datasource=github-releases depName=mozilla/sops
ENV SOPS_VERSION=v3.7.0
RUN \
  curl -fsSL -o "/usr/local/bin/sops" \
    "https://github.com/mozilla/sops/releases/download/${SOPS_VERSION}/sops-${SOPS_VERSION}.linux"\
  && chmod +x /usr/local/bin/sops \
  && sops --version

# renovate: datasource=github-releases depName=stern/stern
ENV STERN_VERSION=v1.20.0
RUN \
  curl -fsSL "https://github.com/stern/stern/releases/download/${STERN_VERSION}/stern_${STERN_VERSION#*v}_linux_arm64.tar.gz" \
    | tar xvz -f - --strip-components=1 -C /tmp \
  && mv /tmp/stern /usr/local/bin/stern \
  && stern --version \
  && rm -rf /tmp/*

# renovate: datasource=github-releases depName=sachaos/viddy
ENV VIDDY_VERSION=v0.3.0
RUN \
  curl -fsSL "https://github.com/sachaos/viddy/releases/download/${VIDDY_VERSION}/viddy_${VIDDY_VERSION#*v}_Linux_arm64.tar.gz" \
    | tar xvz -f - -C /tmp \
  && mv /tmp/viddy /usr/local/bin/viddy \
  && stern --version \
  && rm -rf /tmp/*

COPY --from=flux /usr/local/bin/flux /usr/local/bin/flux
RUN flux --version

COPY --from=hadolint /bin/hadolint /usr/local/bin/hadolint
RUN hadolint --version

COPY --from=helm /usr/bin/helm /usr/local/bin/helm
RUN helm version

COPY --from=helm-docs /usr/bin/helm-docs /usr/local/bin/helm-docs
RUN helm-docs --version

COPY --from=kube-score /kube-score /usr/local/bin/kube-score
RUN kube-score version

COPY --from=kubectl /opt/bitnami/kubectl/bin/kubectl /usr/local/bin/kubectl
RUN kubectl version --client

COPY --from=kubeval /usr/bin/kubeval /usr/local/bin/kubeval
RUN kubeval --version

COPY --from=kubesec /bin/kubesec /usr/local/bin/kubesec
RUN kubesec version

COPY --from=kustomize /app/kustomize /usr/local/bin/kustomize
RUN kustomize version

COPY --from=shellcheck /bin/shellcheck /usr/local/bin/shellcheck
RUN shellcheck --version

COPY --from=terraform /bin/terraform /usr/local/bin/terraform
RUN terraform version

COPY --from=trivy /usr/local/bin/trivy /usr/local/bin/trivy
RUN trivy --version

COPY --from=yq /usr/bin/yq /usr/local/bin/yq
RUN yq --version

COPY --from=prom /bin/promtool /usr/local/bin/promtool
RUN promtool --version

COPY --from=prom-am /bin/amtool /usr/local/bin/amtool
RUN amtool --version

CMD [ "/bin/fish" ]
