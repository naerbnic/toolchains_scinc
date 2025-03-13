"""Module extensions to use scinc from a local path.

This assumes the scinc toolchain exists in the following directory structure:

- bin/
  - scinc
- lib/
  - sci_<version>/
    - system.sc
  - ...
"""

load("//toolchain/extensions/internal:repo.bzl", "scinc_archive_repo")

visibility("public")

_LATEST_RELEASE = "0.0.1"

_RELEASES = {
  "0.0.1": dict(
    windows = struct(
      url = "https://github.com/naerbnic/sci-compiler/releases/download/v0.0.1/scinc-windows-v0.0.1.zip",
      sha256 = "653150a65a0189d602ca050947e466ce64093860cb704a6d33c7f505159bd68d",
    ),
    linux = struct(
      url = "https://github.com/naerbnic/sci-compiler/releases/download/v0.0.1/scinc-linux-v0.0.1.tgz",
      sha256 = "7822a7b83c3481eab926fbab5261422764bffbabbe2903e467e765c5d6b7bccf",
    ),
    macos = struct(
      url = "https://github.com/naerbnic/sci-compiler/releases/download/v0.0.1/scinc-macos-v0.0.1.tgz",
      sha256 = "a1b08634a0963ed74de2551b5d6381631d540f70c71d5548801cd7deaddb91f5",
    )
  ),
}

def _scinc_release_impl(ctx):
  """Module extension implementation for scinc_local."""
  # Look for tags for this release. Only the top-level module should have a
  # tag. If no tags are found, use _LATEST_RELEASE.
  version = _LATEST_RELEASE
  for module in ctx.modules:
    if module.is_root:
      for version in module.tags.version:
        defined_version = version.version
        if defined_version == "latest":
          version = _LATEST_RELEASE
        elif defined_version in _RELEASES:
          version = defined_version
        else:
          fail("Version {} is not a valid scinc release. Valid versions are: {}"
              .format(defined_version, ", ".join(_RELEASES.keys())))
      continue
    else:
      if len(module.tags.version) > 0:
        fail("Only the root module should set a version for a " +
              "scinc_release extension. Please set the version in the root module.")
  
  ctx_os = ctx.os.name
  # ctx_arch = ctx.os.arch

  if ctx_os.startswith("windows"):
    os = "windows"
  elif ctx_os == "linux":
    os = "linux"
  elif ctx_os == "mac os x":
    os = "macos"
  else:
    fail("Unsupported OS: {}. Supported OS are: windows, linux, macos".format(ctx_os))

  release = _RELEASES[version][os]
  
  scinc_archive_repo(
    name = "scinc_release",
    url = release.url,
    sha256 = release.sha256,
  )

scinc_release = module_extension(
    _scinc_release_impl,
    tag_classes = {
      "version": tag_class(
        doc = "Tag for what version of scinc to use.",
        attrs = {
          "version": attr.string(
            doc = "Version of scinc to use.",
            default = "latest",
          ),
        }
      )
    },
    os_dependent = True,
    arch_dependent = True,
)
