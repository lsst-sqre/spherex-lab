# This functionality is provided in the Rubin Science Platform by the class
# lsst.rsp.startup:
# https://github.com/lsst-sqre/lsst-rsp/tree/main/src/lsst/rsp/startup
# SPHEREx should consider implementing its own version of something like
# that, perhaps using the Rubin class as inspiration

# In a production environment, there will be a lot more you want to do.

for d in WORK DATA notebooks; do
    if [ ! -d "${HOME}/${d}" ]; then
        mkdir -p "${HOME}/${d}"
    fi
done

my_dircolors="${HOME}/.dir_colors"
# Copy dircolors if needed
if [ ! -f "${my_dircolors}" ]; then
    cp /etc/dircolors.ansi-universal "${my_dircolors}"
fi

# Activate dircolors
eval $(dircolors -b "{my_dircolors}")

alias ls='ls --color=auto'
    
