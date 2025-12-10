FROM ghcr.io/ipac-sw/spherex-pipelines:latest AS pipeline-source


FROM ghcr.io/lsst-sqre/nublado-jupyterlab-base:latest AS base-image
USER 0:0
SHELL ["/bin/bash", "-lc"]

RUN mkdir -p /tmp/build
WORKDIR /tmp/build

COPY runtime/spherex-kernel.json \
    /usr/local/share/jupyter/kernels/spherex/kernel.json

FROM base-image AS dep-image
COPY scripts/install-dependency-packages /tmp/build
# Ensure libpq5 is installed (required for Conda env's psycopg2)
RUN apt-get update && apt-get install -y libpq5 && \
    ./install-dependency-packages && \
    rm -rf /var/lib/apt/lists/*

# --- User Creation Stage ---
FROM dep-image AS user-image
COPY scripts/make-user /tmp/build
RUN ./make-user

# Ensure directories exist and are owned by the user
RUN mkdir -p /usr/local/share/jupyterlab \
             /opt/spherex \
             /app \
             /opt/conda \
    && chown -R spherex_local:spherex_local \
             /usr/local/share/jupyterlab \
             /opt/spherex \
             /app \
             /opt/conda \
             /tmp/build

USER spherex_local:spherex_local


FROM user-image AS base-stack-image

# Install Miniforge
RUN curl -L -O "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh" && \
    bash Miniforge3-Linux-x86_64.sh -b -u -p /opt/spherex && \
    rm Miniforge3-Linux-x86_64.sh

# We must restore the environment to /opt/conda/envs/spxpipe-L3
# so that the hardcoded paths inside pip and python executables work.
RUN mkdir -p /opt/conda/envs && \
    chown spherex_local:spherex_local /opt/conda/envs

COPY --chown=spherex_local:spherex_local \
     --from=pipeline-source \
     /opt/conda/envs/spxpipe-L3 /opt/conda/envs/spxpipe-L3

RUN mkdir -p /opt/spherex/envs && \
    ln -s /opt/conda/envs/spxpipe-L3 /opt/spherex/envs/spx-pipe-base

# 4. Copy Editable Source Code
COPY --chown=spherex_local:spherex_local \
     --from=pipeline-source \
     /app/spherex-pipelines /app/spherex-pipelines

FROM base-stack-image AS config-stack-image

# Initialize Shell for Mamba so the next RUN commands can use 'conda activate'
# This ensures 'mamba.sh' is sourced for the build shell
SHELL ["/bin/bash", "--rcfile", "/opt/spherex/etc/profile.d/mamba.sh", "-c"]

RUN mkdir -p /opt/spherex/runtime
COPY --chown=spherex_local:spherex_local runtime/loadspherex \
    runtime/runlab runtime/spherex-kernel.json runtime/spherexlaunch.bash \
    /opt/spherex/runtime/

COPY scripts/generate-versions /tmp/build

RUN ./generate-versions

# Clean up.
USER 0:0
WORKDIR /

COPY scripts/cleanup-files /
RUN ./cleanup-files
RUN rm ./cleanup-files

# Compatibility link
RUN mkdir -p /opt/lsst/software/jupyterlab && \
    ln -sf /opt/spherex/runtime/runlab /opt/lsst/software/jupyterlab/runlab.sh

# Back to unprivileged
USER 1000:1000
WORKDIR /tmp

CMD ["/opt/spherex/runtime/runlab"]

ENV DESCRIPTION="SPHEREx Lab"
ENV SUMMARY="SPHEREx Jupyterlab environment"
