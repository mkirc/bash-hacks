#!/usr/bin/env bash


# set -x

test1=("a" "b" "c")
test2=("d")
test3=("a" "b")

# Run the examples herein like:
# bash arrayStuff.sh [function name]

# Picture yourself with the need to check if a string is an element if an indexed
# array in bash. So you phrase this task to a search engine (or worse) and the
# following might come up:

# This works by shifting the input elements by one and iterating over the
# elements left. So we cant pass it an array 'directly' but by supplying
# its values.
simpleElementIn() {
    # Args: [Element to find] [Elements possible...]
    # Returns True if element is found, else false.
    local e match="$1"
    shift
    # for without 'in' implicitly iterates over the
    # (shifted) argument list.
    for e; do [[ "$e" == "$match" ]] && return 0; done
    return 1
}

test_elementsIn() {
    simpleElementIn 'a' "${test1[@]}" && echo "should work"
    simpleElementIn 'd' "${test1[@]}" && echo "should fail"
}

# This is a modified version, which uses the declare's '-n' flag, which allows to
# pass an array by reference. This feels cleaner and requires less typing.
elementIn() {
    # Args: [Element to match]:String [Array to match]:Array
    local match="$1"
    local -n arrayToMatch="$2"

    for elm in "${arrayToMatch[@]}"; do
        [[ "$elm" == "$match" ]] && return 0
     done
    return 1
}

test_noShiftElementsIn() {
    elementIn 'a' test1 && echo 'should work'
    elementIn 'd' test1 && echo 'should fail'
}

# Nice. So next we may want a function which can test for all elements of another
# array (lets call it array1), if its elements are element of another array (lets
# call that array2)

# A simple solution would be to just iterate over array1 and apply 'elementIn' to
# its elements and array2...
allElementsIn() {
    local -n array1="$1"
    local -n array2="$2"

    for elm in "${array1[@]}"; do
        elementIn "$elm" array2 || return 1
    done
    return 0
}

test_allElementsIn() {
    allElementsIn test1 test1 && echo 'should work'
    allElementsIn test3 test1 && echo 'should also work'
    allElementsIn test2 test1 && echo 'should fail'
}
# ... which works but feels boring, right? We can do better. Since the
# fundamental type in shell is just the String, we can evaluate an expression
# by just passing its name:

# This function can take an expression, which itself is acting on a single
# element and an array, in order to perform its action on all elements of an
# input array. Note how it composes nicely by juxtaposition.
all() {
    # Args: Expression Array Array
    expression="$1"
    local -n array1="$2"
    local -n array2="$3"

    for elm in "${array1[@]}"; do
        "$expression" "$elm" array2 || return 1
    done
    return 0

}
test_all_elementsIn() {
    all elementIn test1 test1 && echo 'should work'
    all elementIn test3 test1 && echo 'should also work'
    all elementIn test2 test1 && echo 'should fail'
}

# So it seems our array-and-strings-based life in the shell is good.
# We can define clean interfaces with minimal responsibility and
# pass around arrays without typing "${[@]}" all the time.
# But now consider that:

# This example exposes a problem with call-by-reference: external commands can't
# access array2. This function works when composed with 'simpleElementIn', since
# the values of array2 are actually expanded to the command line. Note, that the
# whole thing only works by allowing recursive dispatch on the script, which is
# arguably esoteric already.
parallelAll() {
    local exp="$1"
    local -n array1="$2"
    local -n array2="$3"

    echo "${array1[@]}" | xargs bash "$0" "$exp" $(cat /dev/stdin) "${array2[@]}"
}

test_parallel() {
    parallelAll simpleElementIn test1 test1 && echo "should work"
    parallelAll simpleElementIn test3 test1 && echo "should also work"
    parallelAll simpleElementIn test2 test1 && echo "should fail"
}

# So here we have found a discrepancy: We can compose array-based functions
# inside of the script's scope nicely but we can't pass them _to_ our script.
# This can only be done by passing the values, which poses addional overhead to
# ensure compatibility (such as parsing values into arrays again). This is the
# perfect place for bugs to crawl in.

# There is but a loophole: Its in fact possible to pass arrays to functions
# delared in other scripts by source'ing them. 'source' can take
# arguments and since it executes the commands in the current shell,
# variables 'carry over'. I guess here we go down even further in the
# rabbit hole of esoteric-but-may-be-useful shell aspects. But think about
# it: This technique can be used to create an array-based 'functional core'
# of scripts than can be factored in a sane fashion, which in turn can be
# directed by an 'impoerative shell', which acts like any other shell
# script as in 'does not accept arrays as argument'.
test_source() {
    source ./arrays/toBeSourced.sh arrayFun test1
}

source ./dispatch/recursive_dispatch.sh
