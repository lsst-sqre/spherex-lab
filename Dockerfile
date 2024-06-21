FROM python:3.12 as base-image
USER root
SHELL ["/bin/bash", "-lc"]

RUN mkdir -p /tmp/build
WORKDIR /tmp/build

COPY scripts/install-base-packages /tmp/build
RUN ./install-base-packages

# Now we have a patched python container.  Add system dependencies.

FROM base-image as deps-image
COPY scripts/install-dependency-packages /tmp/build
RUN ./install-dependency-packages

FROM deps-image as sys-image
COPY skel/pythonrc /etc/skel/.pythonrc

COPY profile.d/local01-nbstripjq.sh \
     profile.d/local02-pythonrc.sh \
     profile.d/local03-path.sh \
     profile.d/local04-term.sh \
     profile.d/local05-setupstack.sh \
     profile.d/local06-setupuser.sh \
     /etc/profile.d/

COPY jupyter_server/jupyter_server_config.json \
     jupyter_server/jupyter_server_config.py \
     /usr/local/etc/jupyter/

COPY runtime/spherex-kernel.json \
    /usr/local/share/jupyter/kernels/spherex/kernel.json

COPY scripts/install-system-files /tmp/build
RUN ./install-system-files

# Add our new unprivileged user.

FROM sys-image as user-image

COPY scripts/make-user /tmp/build
RUN ./make-user

# Give jupyterlab ownership to unprivileged user

RUN mkdir -p /usr/local/share/jupyterlab /opt/spherex && \
    chown -R spherex_local:spherex_local \
    /usr/local/share/jupyterlab /opt/spherex /tmp/build

# Switch to unprivileged user

USER spherex_local:spherex_local

# Add the SPHEREx stack.

FROM user-image as base-stack-image

COPY scripts/install-spherex /tmp/build
COPY spherex-pipelines-base.yml /tmp/build
RUN ./install-spherex

FROM base-stack-image as jupyterlab-image
COPY scripts/install-jupyterlab /tmp/build
RUN ./install-jupyterlab

FROM jupyterlab-image as config-stack-image
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
    ln -s /opt/spherex/runtime/runlab /opt/lsst/software/jupyterlab/runlab.sh

# Back to unprivileged
USER 1000:1000
WORKDIR /tmp

CMD ["/opt/spherex/runtime/runlab"]

# Overwrite Stack Container definitions with more-accurate-for-us ones
ENV  DESCRIPTION="SPHEREx Lab"
ENV  SUMMARY="SPHEREx Jupyterlab environment"
