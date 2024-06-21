#!/bin/bash
CONFIG_FILE=$1

# Load the appropriate conda environment
source /opt/spherex/runtime/loadspherex

# And now transfer control over to Python
exec python3 -m ipykernel -f ${CONFIG_FILE}
