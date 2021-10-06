# dependencies
FROM docker.io/alpine/helm:3.7.0 as helm
FROM docker.io/argoproj/argocli:v3.1.13 as argo-cli
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
FROM registry.fedoraproject.org/fedora:35@sha256:b7bb22ac74a4cdad8fa64341cb2f665a5ca9301b526437fb62013457fea605b2

WORKDIR /opt/toolbox

ENV GOPATH="/opt/toolbox/go"
ENV PATH="$PATH:/opt/toolbox/node_modules/.bin:${GOPATH}/bin"

RUN \
  sed -i '/tsflags=nodocs/d' /etc/dnf/dnf.conf \
  && echo "installonly_limit=15" | tee -a /etc/dnf/dnf.conf \
  && echo "max_parallel_downloads=20" | tee -a /etc/dnf/dnf.conf

# renovate: datasource=repology depName=fedora_35
ENV BELOW_VERSION=0.3.0
# renovate: datasource=repology depName=fedora_35
ENV FISH_VERSION=3.3.1
# renovate: datasource=repology depName=fedora_35
ENV GO_VERSION=1.16.8
# renovate: datasource=repology depName=fedora_35
ENV NODE_VERSION=16.10.0
# renovate: datasource=repology depName=fedora_35
ENV NPM_VERSION=7.24.0
# renovate: datasource=repology depName=fedora_35
ENV TMATE_VERSION=2.4.0

RUN \
  dnf install -y \
    acl \
    automake \
    bash \
    bash-completion \
    bc \
    below-${BELOW_VERSION} \
    bzip2 \
    curl \
    diffutils \
    dnf-plugins-core \
    findutils \
    fish-${FISH_VERSION} \
    flatpak-spawn \
    fpaste \
    gawk \
    git \
    gnupg \
    gnupg2-smime \
    golang-${GO_VERSION} \
    grep \
    gvfs-client \
    gzip \
    hostname \
    iproute \
    iputils \
    jwhois \
    keyutils \
    krb5-libs \
    less \
    libcap \
    libffi-devel \
    lsof \
    man-db \
    man-pages \
    mlocate \
    mtr \
    nano-default-editor \
    nodejs-${NODE_VERSION} \
    npm-${NPM_VERSION} \
    nss-mdns \
    openssl \
    openssh-clients \
    openssl-devel \
    p11-kit \
    pam \
    passwd \
    pigz \
    procps-ng \
    python \
    python-devel \
    python-pip \
    python-setuptools \
    python-six \
    rpm \
    rsync \
    sed \
    shadow-utils \
    sudo \
    systemd \
    tar \
    tcpdump \
    time \
    tmate-${TMATE_VERSION} \
    tmux \
    traceroute \
    tree \
    unzip \
    vte-profile \
    wget \
    which \
    words \
    xorg-x11-xauth \
    xz \
    zip

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
  && ansible --version

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

COPY --from=argo-cli   /bin/argo                        /usr/local/bin/argo
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

CMD [ "/bin/sh" ]

ENV NAME=fedora-toolbox VERSION=35
LABEL org.opencontainers.image.source https://github.com/onedr0p/coolbox \
      com.github.containers.toolbox="true" \
      com.redhat.component="$NAME" \
      name="$NAME" \
      version="$VERSION" \
      usage="This image is meant to be used with the toolbox command" \
      summary="Fedora toolbox" \
      maintainer="Devin Buhl <devin.kray@gmail.com>"
