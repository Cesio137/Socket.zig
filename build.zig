const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    // This creates a "module", which represents a collection of source files alongside
    // some compilation options, such as optimization mode and linked system libraries.
    // Every executable or library we compile will be based on one or more modules.
    const lib_mod = b.createModule(.{
        // `root_source_file` is the Zig "entry point" of the module. If a module
        // only contains e.g. external object files, you can make this `null`.
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // We will also create a module for our other entry point, 'main.zig'.
    const exe_mod = b.createModule(.{
        // `root_source_file` is the Zig "entry point" of the module. If a module
        // only contains e.g. external object files, you can make this `null`.
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Modules can depend on one another using the `std.Build.Module.addImport` function.
    // This is what allows Zig source code to use `@import("foo")` where 'foo' is not a
    // file path. In this case, we set up `exe_mod` to import `lib_mod`.
    exe_mod.addImport("Socket_zig_lib", lib_mod);

    // Setup libuv
    const libuv = setupLibuv(b, target, optimize);

    // Now, we will create a static library based on the module we created above.
    // This creates a `std.Build.Step.Compile`, which is the build step responsible
    // for actually invoking the compiler.
    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "Socket_zig",
        .root_module = lib_mod,
    });

    // This declares intent for the library to be installed into the standard
    // location when the user invokes the "install" step (the default step when
    // running `zig build`).
    lib.addIncludePath(b.path("vendor/libuv/include"));
    lib.linkLibrary(libuv);
    b.installArtifact(lib);

    // This creates another `std.Build.Step.Compile`, but this one builds an executable
    // rather than a static library.
    const exe = b.addExecutable(.{
        .name = "Socket_zig",
        .root_module = exe_mod,
    });

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    exe.addIncludePath(b.path("vendor/libuv/include"));
    exe.linkLibrary(libuv);
    b.installArtifact(exe);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const lib_unit_tests = b.addTest(.{
        .root_module = lib_mod,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const exe_unit_tests = b.addTest(.{
        .root_module = exe_mod,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_exe_unit_tests.step);
}

pub fn setupLibuv(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Step.Compile {
    var uv = b.addStaticLibrary(.{ 
        .name = "uv", 
        .target = target, 
        .optimize = optimize,
    });
    uv.addIncludePath(b.path("vendor/libuv/include"));
    uv.addIncludePath(b.path("vendor/libuv/src"));
    uv.linkLibC();

    //var flags = std.ArrayList([]const u8).init(b.allocator);
    //defer flags.deinit();

    uv.addCSourceFiles(.{
        .files = &.{
            "vendor/libuv/src/fs-poll.c",
            "vendor/libuv/src/idna.c",
            "vendor/libuv/src/inet.c",
            "vendor/libuv/src/random.c",
            "vendor/libuv/src/strscpy.c",
            "vendor/libuv/src/strtok.c",
            "vendor/libuv/src/threadpool.c",
            "vendor/libuv/src/timer.c",
            "vendor/libuv/src/uv-common.c",
            "vendor/libuv/src/uv-data-getter-setters.c",
            "vendor/libuv/src/version.c",
        }
    });
    
    if (target.result.os.tag == .windows) {
        uv.addCSourceFiles(.{
            .files = &.{
                "vendor/libuv/src/win/async.c",
                "vendor/libuv/src/win/core.c",
                "vendor/libuv/src/win/detect-wakeup.c",
                "vendor/libuv/src/win/dl.c",
                "vendor/libuv/src/win/error.c",
                "vendor/libuv/src/win/fs.c",
                "vendor/libuv/src/win/fs-event.c",
                "vendor/libuv/src/win/getaddrinfo.c",
                "vendor/libuv/src/win/getnameinfo.c",
                "vendor/libuv/src/win/handle.c",
                "vendor/libuv/src/win/loop-watcher.c",
                "vendor/libuv/src/win/pipe.c",
                "vendor/libuv/src/win/thread.c",
                "vendor/libuv/src/win/poll.c",
                "vendor/libuv/src/win/process.c",
                "vendor/libuv/src/win/process-stdio.c",
                "vendor/libuv/src/win/signal.c",
                "vendor/libuv/src/win/snprintf.c",
                "vendor/libuv/src/win/stream.c",
                "vendor/libuv/src/win/tcp.c",
                "vendor/libuv/src/win/tty.c",
                "vendor/libuv/src/win/udp.c",
                "vendor/libuv/src/win/util.c",
                "vendor/libuv/src/win/winapi.c",
                "vendor/libuv/src/win/winsock.c",
            }
        });

        uv.linkSystemLibrary("psapi");
        uv.linkSystemLibrary("user32");
        uv.linkSystemLibrary("advapi32");
        uv.linkSystemLibrary("iphlpapi");
        uv.linkSystemLibrary("userenv");
        uv.linkSystemLibrary("ws2_32");
        uv.linkSystemLibrary("dbghelp");
        uv.linkSystemLibrary("ole32");
        uv.linkSystemLibrary("shell32");
        uv.linkSystemLibrary("ucrtbased");
    }

    if (target.result.os.tag == .linux) {
        uv.addCSourceFiles(.{
            .files = &.{
                "vendor/libuv/src/unix/async.c",
                "vendor/libuv/src/unix/core.c",
                "vendor/libuv/src/unix/dl.c",
                "vendor/libuv/src/unix/fs.c",
                "vendor/libuv/src/unix/getaddrinfo.c",
                "vendor/libuv/src/unix/getnameinfo.c",
                "vendor/libuv/src/unix/loop-watcher.c",
                "vendor/libuv/src/unix/loop.c",
                "vendor/libuv/src/unix/pipe.c",
                "vendor/libuv/src/unix/poll.c",
                "vendor/libuv/src/unix/process.c",
                "vendor/libuv/src/unix/proctitle.c",
                "vendor/libuv/src/unix/random-devurandom.c",
                "vendor/libuv/src/unix/signal.c",
                "vendor/libuv/src/unix/stream.c",
                "vendor/libuv/src/unix/tcp.c",
                "vendor/libuv/src/unix/thread.c",
                "vendor/libuv/src/unix/tty.c",
                "vendor/libuv/src/unix/udp.c",
            },
            .flags = &.{
                "-D_FILE_OFFSET_BITS=64",
                "-D_LARGEFILE_SOURCE",
                "-D_GNU_SOURCE",
                "-D_POSIX_C_SOURCE=200112"
            }
        });
        uv.addCSourceFiles(.{
            .files = &.{
                "vendor/libuv/src/unix/linux.c",
                "vendor/libuv/src/unix/procfs-exepath.c",
                "vendor/libuv/src/unix/random-getrandom.c",
                "vendor/libuv/src/unix/random-sysctl-linux.c",
            },
            .flags = &.{
                "-D_GNU_SOURCE",
                "-D_POSIX_C_SOURCE=200112"
            }
        });
        
        uv.linkSystemLibrary("pthread");
        uv.linkSystemLibrary("dl");
        uv.linkSystemLibrary("rt");
    }

    return uv;
}
