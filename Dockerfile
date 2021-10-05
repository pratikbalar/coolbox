# dependencies
FROM docker.io/alpine/helm:3.7.0 as helm
FROM docker.io/aquasec/trivy:0.19.2 as trivy
FROM docker.io/bitnami/kubectl:1.22.2 as kubectl
FROM docker.io/cytopia/kubeval:0.16 as kubeval
FROM docker.io/fluxcd/flux-cli:v0.17.2 as flux
FROM docker.io/hadolint/hadolint:v2.7.0 as hadolint
FROM docker.io/hashicorp/terraform:1.0.8 as terraform
FROM docker.io/jnorwood/helm-docs:v1.5.0 as helm-docs
FROM docker.io/koalaman/shellcheck:v0.7.2 as shellcheck
FROM docker.io/kubesec/kubesec:v2.11.4 as kubesec
FROM docker.io/mikefarah/yq:4.13.3 as yq
FROM docker.io/prom/alertmanager:v0.23.0 as prom-am
FROM docker.io/prom/prometheus:v2.30.3 as prom
FROM docker.io/zegl/kube-score:v1.12.0 as kube-score
FROM k8s.gcr.io/kustomize/kustomize:v4.4.0 as kustomize

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

RUN \
  set -eux \
  && echo 'APT::Install-Recommends "false";' >/etc/apt/apt.conf.d/00recommends \
  && echo 'APT::Install-Suggests "false";' >>/etc/apt/apt.conf.d/00recommends \
  && echo 'APT::Get::Install-Recommends "false";' >>/etc/apt/apt.conf.d/00recommends \
  && echo 'APT::Get::Install-Suggests "false";' >>/etc/apt/apt.conf.d/00recommends \
  && \
  apt-get update -qy \
  && apt-get install -qy \
    acl \
    apt-transport-https \
    bash \
    bzip2 \
    ca-certificates \
    curl \
    diffutils \
    findutils \
    git \
    gnupg \
    gawk \
    grep \
    gzip \
    hostname \
    iputils-tracepath \
    jq \
    keyutils \
    less \
    libcap2 \
    lsof \
    lsb-release \
    mlocate \
    mtr \
    nano \
    openssl \
    passwd \
    pigz \
    p11-kit \
    python3 \
    python3-dev \
    python3-pip \
    rclone \
    rsync \
    sed \
    software-properties-common \
    sudo \
    tar \
    tcpdump \
    time \
    tmux \
    traceroute \
    tree \
    wget \
    # shfmt \
    unzip \
    zip \
  && \
  apt-get purge -qy --auto-remove -o APT::AutoRemove::RecommendsImportant=false && \
  apt-get autoremove -qy && \
  apt-get clean -qy && \
  rm -rf \
    /tmp/* \
    /var/lib/apt/lists/* \
    /var/cache/apt/* \
    /var/tmp/*

RUN echo "Defaults exempt_group=sudo" > /etc/sudoers.d/exempt_group

# install fish shell
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

# nodejs
COPY package*.json .
RUN \
  npm ci --only=production \
  && markdownlint --version \
  && prettier --version \
  && semantic-release --version

# python
COPY requirements.txt .
RUN \
  pip install --no-cache-dir -r requirements.txt \
  && \
  aws --version \
  && yamllint --version \
  && find /usr/lib/ -name '__pycache__' -print0 | xargs -0 -n1 rm -rf \
  && find /usr/lib/ -name '*.pyc' -print0 | xargs -0 -n1 rm -rf

# renovate: datasource=github-releases depName=twpayne/chezmoi
ENV CHEZMOI_VERSION=v2.6.1
RUN \
  curl -fsSL "https://github.com/twpayne/chezmoi/releases/download/${CHEZMOI_VERSION}/chezmoi_${CHEZMOI_VERSION#*v}_linux_amd64.tar.gz" \
    | tar xvz -f - -C /tmp \
  && mv /tmp/chezmoi /usr/local/bin/chezmoi \
  && chezmoi --version \
  && rm -rf /tmp/*

# renovate: datasource=github-releases depName=sbstp/kubie
ENV KUBIE_VERSION=v0.15.1
RUN \
  curl -fsSL -o "/usr/local/bin/kubie" \
    "https://github.com/sbstp/kubie/releases/download/${KUBIE_VERSION}/kubie-linux-amd64" \
  && chmod +x /usr/local/bin/kubie \
  && kubie --version

# renovate: datasource=github-releases depName=mozilla/sops
ENV SOPS_VERSION=v3.7.1
RUN \
  curl -fsSL -o /usr/local/bin/sops \
    "https://github.com/mozilla/sops/releases/download/${SOPS_VERSION}/sops-${SOPS_VERSION}.linux" \
  && chmod +x /usr/local/bin/sops \
  && sops --version

# renovate: datasource=github-releases depName=mvdan/sh
ENV SHFMT_VERSION=v3.4.0
RUN \
  curl -fsSL -o /usr/local/bin/shfmt \
    "https://github.com/mvdan/sh/releases/download/${SHFMT_VERSION}/shfmt_${SHFMT_VERSION}_linux_amd64" \
  && chmod +x /usr/local/bin/shfmt \
  && shfmt --version

# renovate: datasource=github-releases depName=starship/starship
ENV STARSHIP_VERSION=v0.58.0
RUN \
  curl -fsSL "https://github.com/starship/starship/releases/download/${STARSHIP_VERSION}/starship-x86_64-unknown-linux-gnu.tar.gz" \
    | tar xvz -f - -C /tmp \
  && mv /tmp/starship /usr/local/bin/starship \
  && starship --version \
  && rm -rf /tmp/*

# renovate: datasource=github-releases depName=stern/stern
ENV STERN_VERSION=v1.20.1
RUN \
  curl -fsSL "https://github.com/stern/stern/releases/download/${STERN_VERSION}/stern_${STERN_VERSION#*v}_linux_amd64.tar.gz" \
    | tar xvz -f - --strip-components=1 -C /tmp \
  && mv /tmp/stern /usr/local/bin/stern \
  && stern --version \
  && rm -rf /tmp/*

# renovate: datasource=github-releases depName=go-task/task
ENV TASK_VERSION=v3.9.0
RUN \
  curl -fsSL "https://github.com/go-task/task/releases/download/${TASK_VERSION}/task_linux_amd64.tar.gz" \
    | tar xvz -f - -C /tmp \
  && mv /tmp/task /usr/local/bin/task \
  && task --version \
  && rm -rf /tmp/*

# renovate: datasource=github-releases depName=sachaos/viddy
ENV VIDDY_VERSION=v0.3.1
RUN \
  curl -fsSL "https://github.com/sachaos/viddy/releases/download/${VIDDY_VERSION}/viddy_${VIDDY_VERSION#*v}_Linux_x86_64.tar.gz" \
    | tar xvz -f - -C /tmp \
  && mv /tmp/viddy /usr/local/bin/viddy \
  && viddy --version \
  && rm -rf /tmp/*

COPY --from=flux       /usr/local/bin/flux              /usr/local/bin/flux
COPY --from=hadolint   /bin/hadolint                    /usr/local/bin/hadolint
COPY --from=helm       /usr/bin/helm                    /usr/local/bin/helm
COPY --from=helm-docs  /usr/bin/helm-docs               /usr/local/bin/helm-docs
COPY --from=kube-score /kube-score                      /usr/local/bin/kube-score
COPY --from=kubectl    /opt/bitnami/kubectl/bin/kubectl /usr/local/bin/kubectl
COPY --from=kubesec    /bin/kubesec                     /usr/local/bin/kubesec
COPY --from=kubeval    /usr/bin/kubeval                 /usr/local/bin/kubeval
COPY --from=kustomize  /app/kustomize                   /usr/local/bin/kustomize
COPY --from=prom       /bin/promtool                    /usr/local/bin/promtool
COPY --from=prom-am    /bin/amtool                      /usr/local/bin/amtool
COPY --from=shellcheck /bin/shellcheck                  /usr/local/bin/shellcheck
COPY --from=terraform  /bin/terraform                   /usr/local/bin/terraform
COPY --from=trivy      /usr/local/bin/trivy             /usr/local/bin/trivy
COPY --from=yq         /usr/bin/yq                      /usr/local/bin/yq

CMD [ "/bin/fish" ]

LABEL org.opencontainers.image.source https://github.com/onedr0p/coolbox
LABEL com.github.containers.toolbox="true"
