# argwork - shell command, completed

`argwork` is a concept, an idea, that you can define a domain for your shell command in native terms and then let completion, usage and inspection work with no additional code required.


## How it works

In a prepared _Stack_ create a new _quasi command_:
1. Put `<name><SPACE>.sh` in any subdirectory of the stack root.
2. Specify command inputs by defining your command domain.
3. Put your action inside `main()`.

Invoke the command using the runner with the completion built in.

```
[argwork-completion.bash]
                          \
                            [argwork quasi command]
                          /
    [argwork runner]
```

Basic outline for a _quasi command_:

```bash
at <...>
...

main() {
  <your code>
}
```

When _completion_ script is triggered the actual _quasi command_ script is `source`-d to provide implementation for `at` commands.
That is why the actual command code is put into `main()` function, i.e. to protect it from being run by _completion_ script.

`main()` will be invoked only by the `argwork` _runner_ executable script.

### Parameter specification:

```bash
at  <index>  <name>  _       # Matches any input

at  <index>  <name>  text     {eq | lt | gt | le | ge} <number>
at  <index>  <name>  regex    <pattern>
at  <index>  <name>  uuid
at  <index>  <name>  date
at  <index>  <name>  integer

at  <index>  <name>  file
at  <index>  <name>  dir

at  <index>  <name>  from     path/to/source
at  <index>  <name>  opts     <option #1> {... <option #N>}
at  <index>  <name>  command  <command | cmd> {arg 1} {arg 2} ...
at  <index>  <name>  shell    <shell script>

at  <index>  <name>  ...      # Dynamic continuation marker
```

`name` is a environment variable name that will be created and assigned a value corresponding to either positional of optional argument.

`<index>` can be one of the following:
* `1` `2` ... for **positional** parameter
* `_` for an **optional** parameter

### Positional parameters
Those are positional in traditional understanding. There must be no gaps in numbering, although there is no requirement for a strict ordering (i.e. #2 can follow #4 as long as there is #3 specified at some point as well).

### Optional parameters
Those can be omitted, or specified only once, e.g.:

```bash
at  1  level   opts  WARN DEBUG
at  _  target  opts  alpha beta other
```

It is possible to have a _quasi command_ with no positional **or** no optional parameters.

The actual command may look like:

```bash
run DEBUG target: alpha
```

Sometimes it may be convenient to keep the optional name while omitting it as it were not specified at all.
This may be achieved by specifying `_` in place of a value:

```bash
run WARN env: _
```

### Parameter ordering
Positional arguments must immediately follow command name.

Optional arguments must follow positional arguments.

## Install

### Manual installation

* Put `argwork` executable on `PATH`
* Source `argwork-completion.bash` in `.bashrc`

Use symbolic links (`ln`) to make `git pull` automatically update with new changes.

```bash
ln -s argwork ~/.bin/argwork
ln -s bash-completion.sh ~/.config/argwork/bash-completion.sh
```

Add to `.bashrc`:

```bash
source ~/.config/argwork/bash-completion.sh
```

## CLI

* Positional arguments immediately follow the `<command> <quasi command>`
* Optional arguments must follow positional and their value must be preceded by `<parameter name>:`
* ` ?<TAB><TAB>` at the end of the command line will print `usage:` information
* `??<TAB><TAB>` at the end of the command line will print `usage: (current)`, i.e. how arguments are bound to parameters

Example _quasi command_ `random` in `draw` stack:
```bash
at 1 color   opts  red green yellow
at 2 fruit   opts  papaya mango jackfruit durian
at _ rating  integer

main () {
  echo "$color $fruit is rated ${rating:-friendly}"
}
```

Command line may look something like:

```bash
$ draw random green ?<TAB><TAB>
usage:  [1:color]  [2:fruit]  (rating)

$ draw random yellow mango ??<TAB><TAB>
usage (current):
  1:color    = yellow
  2:fruit    = mango
  _:rating   =
```

## Setting up new command stack

Related _quasi commands_ would likely share some assets or routines that make writing _quasi commands_ more convenient. Those _quasi commands_ can be organized by designating a certain root directory where all assets would be shared. This is called `argwork` _Stack_, while the directory is called `argwork` _Stack base_.

It is recommended to use a semantic name for each new stack command so there would be no collision or accidental mix up of stacks.

### Completion configuration

Create a completion loader, e.g.:

```bash
_run_completion() {
  ARGWORK_CLI_DIR="$HOME/path/to/stack/base"
  _argwork_completion
}

complete -o nosort -F _run_completion run
```

Use one of the following options:

* Create a new bash script with code similar to the following
* Add or source the snippet in `.bashrc`
* Put the file into `/usr/share/bash-completion/completions/`


### Runner configuration

Create a file names `run` on `PATH`, with the following content:

```bash
#!/bin/bash

export ARGWORK_CLI_DIR="$HOME/path/to/stack/base"
argwork "$@"
```

### Command stack framework

_Stack base_ directory is defined by `ARGWORK_CLI_DIR` environment variable and tells the runner and completion where to lookup the assets.
Establishing _Stack base_ is required for making _quasi commands_ discoverable inside subdirectories to form user-friendly path to the actual command, e.g.:
```
run path/to/command argument
```

#### Assets
Assets are automatically discoverable in places where assets are expected.

Directories:

* `.bin` contains executable assets are made discoverable for `cmd` (same as `command`) without being on `PATH`
* `.opts` contains asset files whose content will be used for sourcing `from` parameter specification

Files:
* `.env.sh` - contains a script that will be included before each _quasi command_ (i.e. global configuration)


When you have a _quasi command_ and have a need for either `.env.sh` configuration or `from` parameter (i.e. sourcing possible argument values from a file) then you must have defined a root directory for performing the respective file lookup.

### Naming convention
* File with names `<name><SPACE>.sh` will be interpreted as _quasi command_.
* Any subdirectory will be used to structure a path to a _quasi command_ and will be separated by `/` when building a command.

Names are case sensitive due to originating in a physical file system.

### Example
An example of a _Stack base_ that would model a database access tool set:

```
.bin
.opts
cassandra
  |
    shell .sh
    dsbulk
      |
        load .sh
        unload .sh
postgres
  |
    shell .sh
keyspaces
.env.sh
```

After implementing `unload.sh` accordingly, you can export data from _Cassandra_ database by running the following command. It will be provided with completion for `keyspace` and `format` and will check the correctness of `table_name` format when actually run on command line:

```bash
run cassandra/dsbulk/unload table_name  format: csv
```

Note how `cassandra`/`dsbulk`/`unload .sh` physical path (relative to _Stack base_) is expected in a more readable form `cassandra/dsbulk/unload`.

Example of `unload.sh`:

```bash
#!/bin/bash

at 1  keyspace    from   keyspaces
at 2  table_name  regex  '^[a-zA-Z0-9_]*$'
at _  format      opts   csv json

main() {
  dsbulk unload -k "$keyspace" -t "$table_name" > "$table_name.${format:-csv}"
}
```

`keyspaces` text file content:

```
apples
oranges
```

Usage examples:

```
$ run cassandra/dsbult/unload oranges supplier format: json
$ run cassandra/dsbult/unload apples seller format: csv
$ run cassandra/dsbult/unload apples farming
```

```
$ run cassandra/dsbult/unload pears supplier
==> value [pears] is not at [keyspaces]

$ run cassandra/dsbult/unload oranges seller format: text
==> value [text] is not in [csv json]
```
