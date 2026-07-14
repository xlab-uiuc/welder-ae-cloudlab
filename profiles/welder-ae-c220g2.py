"""Profile for running Acto on CloudLab. There is one single physical node. The
OS image is hardwired to Ubuntu 22.04. The hardware type is hardwired to
`c220g2`.

Instructions:
Wait for the experiment to start, and then log into the node by either way:

1. (Web-based) clicking on it in the toplogy, and choosing the `shell` menu
option.
2. (Terminal-based) the SSH command you need to login will be provided to you on
the web dashboard, in the form of `ssh <user>@<node>.<cluster>.cloudlab.us`.

Use `sudo` to run root commands.
"""

# Import the Portal object.
import geni.portal as portal
# Import the ProtoGENI library.
import geni.rspec.pg as pg

import os

cl_repo_path            = "/local/repository/"
startup_script_rel_path = "scripts/cloudlab_startup_run_by_geniuser.sh"
hostname                = "acto-physical-worker-0"

# Create a portal context, needed to defined parameters
pc = portal.Context()

# Create a Request object to start building the RSpec.
request = pc.makeRequestRSpec()

# Fixate parameters
osImage  = 'urn:publicid:IDN+emulab.net+image+emulab-ops//UBUNTU22-64-STD'
phystype = 'c220g2'

node = request.RawPC(hostname)
node.disk_image    = osImage
node.hardware_type = phystype

# Acto startup
startup_script_path = os.path.join(cl_repo_path, startup_script_rel_path)
# node.addService(pg.Execute(shell="bash", command=startup_script_path))

# Print the RSpec to the enclosing page.
pc.printRequestRSpec(request)
