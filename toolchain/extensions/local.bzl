"""Module extensions to use scinc from a local path.

This assumes the scinc toolchain exists in the following directory structure:

- bin/
  - scinc
- lib/
  - sci_<version>/
    - system.sc
  - ...
"""

load("//toolchain/extensions/internal:repo.bzl", "scinc_local_path_repo")

def _scinc_local_impl(ctx):
    """Module extension implementation for scinc_local."""
    home_path = ctx.getenv("SCINC_HOME")
    if home_path:
        scinc_local_path_repo(
            name = "scinc_local",
            scinc_home = home_path,
        )
    else:
        fail("SCINC_HOME environment variable is not set. Please set it to the path of your scinc installation.")

scinc_local = module_extension(
    _scinc_local_impl,
    environ = [
        "SCINC_HOME",
    ],
)
