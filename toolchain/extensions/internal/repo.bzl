"""Internal repo generation rules for scinc."""

load("@bazel_skylib//lib:paths.bzl", "paths")

visibility("//toolchain/extensions/...")

_BUILD_FILE = '''
load(":toolchain.bzl", "scinc_local_toolchain")

scinc_local_toolchain(
  name = "scinc_local"
)

toolchain(
    name = "scinc_local_toolchain",
    toolchain = ":scinc_local",
    toolchain_type = "@rules_sci//sci/toolchains:toolchain_type",
)
'''

_SYSTEM_DEF = '''
  SciSystemInfo(
    target_vm = "{target_vm}",
    defines = [
      {defines}
    ],
    system_header_path = "{inc_path}/system.sh",
    include_path = "{inc_path}",
    dep_files = depset([])),
'''

def _scinc_local_path_impl(ctx):
  home_path = ctx.attr.scinc_home
  bin_path = paths.join(home_path, "bin/scinc")
  # For now, assume that we only support SCI 1.1
  system_libs = [
    struct(
      target_vm = "1.1",
      defines = [
        "SCI_1_1",
      ],
      inc_path = paths.join(home_path, "include/sci_1_1"),
    )
  ]

  ctx.symlink(
    bin_path,
    "scinc",
  )

  system_defs = [
    _SYSTEM_DEF.format(
      target_vm = system_lib.target_vm,
      defines = ", ".join([
        '"{define}"'.format(define = define)
        for define in system_lib.defines]),
      inc_path = system_lib.inc_path,
    )
    for system_lib in system_libs
  ]

  ctx.template(
    "toolchain.bzl",
    Label(":toolchain_local.bzl.tmpl"),
    substitutions = {
      "{{SYSTEMS_LIST}}": "\n".join(system_defs),
    },
    executable = False,
  )

  ctx.file(
    "BUILD.bazel",
    content = _BUILD_FILE,
    executable = False,
  )


scinc_local_path_repo = repository_rule(
  _scinc_local_path_impl,
  attrs = {
    "scinc_home": attr.string(
      mandatory = True,
      doc = "Path to the scinc home directory.",
    ),
  },
)