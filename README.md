# Alisc

Alisc is a compiler that allows you to convert declarative `.alisc` 
files into self-contained binaries containing the command aliases.

> **Status:** work in progress. The core compiler, parser, embed format and
> runtime work, but aliases and `requires` checks are not wired up yet.

## How it works

`alisc` embeds a small Zig runtime (`base`) into every binary it produces:

```text
+---------------------------+------------------+------------------+
| base runtime executable   | .alisc source    | trailer (magic)  |
+---------------------------+------------------+------------------+
At runtime the binary reads its own appended source, compiles it in memory,
and dispatches the requested command.
```

## Requirements

- Zig 0.16.0-dev (see build.zig.zon)
- /bin/sh on the target machine

## Configuration

A `.alisc` file has the following format:

```
name "mytool"
version "0.1.0"
author "your name"

// Named template; "{}" is replaced with the command line.
tmpl SHELL "sh -c {}"
tmpl LOG "tee -a mytool.log <<< {}"

// Long-form command
cmd greet {
    desc "Print a greeting"
    run "echo hello"              // run through /bin/sh -c
    args 0                         // exactly 0 required args
    optargs 1                      // at most 1 optional arg
    requires env "HOME"
    requires bin "echo"
    requires file "config.toml"
}

// Shortcut forms
cmd version : run "mytool --version"
cmd list    : exec "ls", "-la"     // spawn directly, no shell

// Template reference
cmd run {
    desc "Run a script via the shell template"
    run SHELL "echo running: $1"
    args 1
}

// Nested subcommands, addressed as "project.build" / "project.clean"
cmd project {
    desc "Project operations"

    cmd build {
        desc "Build the project"
        run LOG "make all"
        optargs 2
    }

    cmd clean {
        desc "Remove build artifacts"
        exec "rm", "-rf", "build"
    }
}

// Aliases
alias g greet
alias pb project.build
```

## Building

```sh
zig build slitch
```

then you can use the binary `./zig-out/bin/alisc` to generate your binaries:

```
alisc [file] [output]
```
