FROM ghcr.io/lsst-sqre/nublado-jupyterlab-base:latest AS base-image
USER 0:0
SHELL ["/bin/bash", "-lc"]

RUN mkdir -p /tmp/build
WORKDIR /tmp/build

COPY runtime/spherex-kernel.json \
    /usr/local/share/jupyter/kernels/spherex/kernel.json

# Add our new unprivileged user.

FROM base-image AS dep-image

COPY scripts/install-dependency-packages /tmp/build
RUN ./install-dependency-packages

FROM dep-image AS user-image

COPY scripts/make-user /tmp/build
RUN ./make-user

# Give jupyterlab ownership to unprivileged user

RUN mkdir -p /usr/local/share/jupyterlab /opt/spherex && \
    chown -R spherex_local:spherex_local \
    /usr/local/share/jupyterlab /opt/spherex /tmp/build

# Switch to unprivileged user

USER spherex_local:spherex_local

# Add the SPHEREx stack.

FROM user-image AS base-stack-image

COPY scripts/install-spherex /tmp/build
COPY spherex-pipelines-base-x86_64.yml spherex-pipelines-base-aarch64.yml \
    /tmp/build
RUN ./install-spherex

FROM base-stack-image AS config-stack-image
RUN mkdir -p /opt/spherex/runtime
COPY --chown=spherex_local:spherex_local runtime/loadspherex \
    runtime/runlab runtime/spherex-kernel.json runtime/spherexlaunch.bash \
    /opt/spherex/runtime/

COPY scripts/generate-versions /tmp/build
RUN ./generate-versions

# Clean up.
# This needs to be numeric, since we will remove /etc/passwd and friends
# while we're running.
USER 0:0
WORKDIR /

COPY scripts/cleanup-files /
RUN ./cleanup-files
RUN rm ./cleanup-files

# Add compatibility for startup with unmodified nublado

RUN mkdir -p /opt/lsst/software/jupyterlab && \
    ln -sf /opt/spherex/runtime/runlab /opt/lsst/software/jupyterlab/runlab.sh

# Back to unprivileged
USER 1000:1000
WORKDIR /tmp

CMD ["/opt/spherex/runtime/runlab"]

# Overwrite Stack Container definitions with more-accurate-for-us ones
ENV  DESCRIPTION="SPHEREx Lab"
ENV  SUMMARY="SPHEREx Jupyterlab environment"
