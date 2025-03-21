# This is a minimal example for allowing recursive $0 dispatch in bash scripts.
# With this technique functions declared in the top-level scope can be used as
# subcommands. Additionally, commands that wrap other commands, such as 'xargs'
# can use those functions with 'COMMAND $0 FUNCTION'.  This can be useful to
# provide a clean interface for dispatching subcommands. These can be factored
# into other files and then be sourced or run in subshells, if they themselves
# need to allow recurive dispatch.  This demo ist inspired by
# http://www.catb.org/%7Eesr/writings/taoup/html/ch06s06.html and
# https://www.oilshell.org/blog/2021/08/xargs.html.

# you can enable recursive_dispatch by putting a `source ./recursive_dispatch.sh`
# on the last line of your script.
function_exists() {
    # bashism to test is function is declared in top level scope.
    # also works for functions sourced from other files.

    declare -F "$1" >/dev/null
}

allow_recursive_dispatch() {
    # Ensure the first argument is a function declared in this file.
    # now commands that run external commands like xargs can call
    # functions like so: 'command $0 FUNCTION_NAME'
    # Furthermore this script can run the functions declared
    # herein as subcommands.
    function_exists "$1" && "$@"
}

allow_recursive_dispatch "$@"

