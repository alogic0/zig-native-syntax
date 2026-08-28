load("//tools:defs.bzl", "zig_library")

def viewer_library(name, srcs = []):
    zig_library(
        name = name,
        srcs = srcs,
        visibility = ["//visibility:public"],
    )
