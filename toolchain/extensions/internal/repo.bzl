"""Internal repo generation rules for scinc."""

load("@bazel_skylib//lib:paths.bzl", "paths")

visibility("//toolchain/extensions/...")

_LOCAL_BUILD_FILE = '''
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

_LOCAL_SYSTEM_DEF = '''
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
        ),
    ]

    ctx.symlink(
        bin_path,
        "scinc",
    )

    system_defs = [
        _LOCAL_SYSTEM_DEF.format(
            target_vm = system_lib.target_vm,
            defines = ", ".join([
                '"{define}"'.format(define = define)
                for define in system_lib.defines
            ]),
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
        content = _LOCAL_BUILD_FILE,
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

_ARCHIVE_SYSTEM_LIB_BUILD_FILE = '''
load("@rules_sci//sci:sci.bzl", "sci_headers", "sci_system")

sci_headers(
  name = "system_headers",
  hdrs = glob(["*.sh"]),
)

sci_system(
  name = "system",
  target_vm = "{target_vm}",
  defines = [
    {defines}
  ],
  system_header = "system.sh",
  deps = [
    ":system_headers",
  ],
  visibility = ["//:__subpackages__"],
)
'''

_ARCHIVE_TOOLCHAIN_LIB = '''
"""Generated toolchain.bzl file for scinc archive"""

load("@rules_sci//sci:sci.bzl", "SciSystemInfo")

def _scinc_archive_toolchain_impl(ctx):
  return [platform_common.ToolchainInfo(
    scic = ctx.executable._compiler,
    systems = [attr[SciSystemInfo] for attr in ctx.attr.systems]
  )]

scinc_archive_toolchain = rule(
  _scinc_archive_toolchain_impl,
  attrs = {
    "systems": attr.label_list(
      providers = [[SciSystemInfo]],
    ),
    "_compiler": attr.label(
      allow_files = True,
      executable = True,
      default = Label(":bin/scinc"),
      cfg = "exec"
    )
  }
)
'''

_ARCHIVE_BUILD_FILE = '''
load(":toolchain.bzl", "scinc_archive_toolchain")
scinc_archive_toolchain(
  name = "scinc_archive",
  systems = [
    {system_targets}
  ],
)

toolchain(
    name = "scinc_toolchain",
    toolchain = ":scinc_archive",
    toolchain_type = "@rules_sci//sci/toolchains:toolchain_type",
)
'''

def _scinc_archive_repo_impl(ctx):
    ctx.download_and_extract(
        ctx.attr.url,
        sha256 = ctx.attr.sha256,
    )

    # For now, assume that we only support SCI 1.1
    system_libs = [
        struct(
            target_vm = "1.1",
            defines = [
                "SCI_1_1",
            ],
            inc_package = "include/sci_1_1",
        ),
    ]

    # Generate build files for each system directory
    for system_lib in system_libs:
        ctx.file(
            paths.join(system_lib.inc_package, "BUILD.bazel"),
            content = _ARCHIVE_SYSTEM_LIB_BUILD_FILE.format(
                target_vm = system_lib.target_vm,
                defines = ", ".join([
                    '"{define}"'.format(define = define)
                    for define in system_lib.defines
                ]),
            ),
            executable = False,
        )

    # Generate the toolchain library
    ctx.file(
        "toolchain.bzl",
        content = _ARCHIVE_TOOLCHAIN_LIB,
        executable = False,
    )

    # Generate the BUILD file for the toolchain
    ctx.file(
        "BUILD.bazel",
        content = _ARCHIVE_BUILD_FILE.format(
            system_targets = ",\n".join([
                '"//{system_lib}:system"'.format(system_lib = system_lib.inc_package)
                for system_lib in system_libs
            ]),
        ),
        executable = False,
    )

scinc_archive_repo = repository_rule(
    _scinc_archive_repo_impl,
    attrs = {
        "url": attr.string(
            mandatory = True,
            doc = "HTTP url of the scinc archive.",
        ),
        "sha256": attr.string(
            mandatory = True,
            doc = "SHA256 hash of the scinc archive.",
        ),
    },
)
