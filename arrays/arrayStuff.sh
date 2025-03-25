#!/usr/bin/env bash


# set -x

test1=("a" "b" "c")
test2=("d")
test3=("a" "b")
test4=("a" "d")
test5=("a" "a" "a")
test6=("a b" "c d")

# Run the examples herein like:
# bash arrayStuff.sh [function name]

# Picture yourself with the need to check of a string is an element if an indexed
# array in bash. So you phrase this task to a search engine (or worse) and the
# following might come up:

# This works by shifting the input elements by one and iterating over the
# elements left. So we cant pass it an array 'directly' but by supplying
# its values.
simpleElementIn() {
    # Args: [Element to find] [Elements possible...]
    # Returns True if element is found, else false.
    local e match="$1"
    echo "$match"
    shift
    # for without 'in' implicitly iterates over the
    # (shifted) argument list.
    for e; do
        [[ "$e" == "$match" ]] && return 0
    done
    return 1
}

test_elementsIn() {
    simpleElementIn 'a' "${test1[@]}" && echo "should work"
    simpleElementIn 'a b' "${test6[@]}" && echo "should also work"
    simpleElementIn 'd' "${test1[@]}" && echo "should fail"
    simpleElementIn 'a' "${test6[@]}" && echo "should also fail"
}

# This is a modified version, using declare's '-n' flag, which allows to
# pass an array by reference. This feels cleaner and requires less typing.
elementInArray() {
    # Args: [Element to match: String] [Array to match: Array]
    local match="$1"
    local -n arrayToMatch="$2"

    # echo "$match"

    for elm in "${arrayToMatch[@]}"; do
        [[ "$elm" == "$match" ]] && return 0
     done
    return 1
}

test_elementInArray() {
    elementInArray 'a' test1 && echo 'should work'
    elementInArray 'a b' test6 && echo 'should also work'
    elementInArray 'd' test1 && echo 'should fail'
    elementInArray 'a' test6 && echo 'should also fail'
}

# Nice. So next we may want a function which can test for all elements of another
# array (lets call it array1), if its elements are element of another array (lets
# call that array2)

# A simple solution would be to just iterate over array1 and apply 'elementInArray' to
# its elements and array2...
allElementsIn() {
    # Args: [Name of Array to compare from: String] [Name of array to compare against: String]
    local -n array1="$1"
    local -n array2="$2"

    for elm in "${array1[@]}"; do
        elementInArray "$elm" array2 || return 1
    done
    return 0
}

test_allElementsIn() {
    allElementsIn test1 test1 && echo 'should work'
    allElementsIn test3 test1 && echo 'should also work'
    allElementsIn test2 test1 && echo 'should fail'
    allElementsIn test4 test1 && echo 'should also fail'
}
# ... which works but feels boring, right? We can do better. Since the
# fundamental type in shell is just the String, we can evaluate an expression
# by just passing its name:

# This function can take an expression, which itself is acting on a single
# element and an array, in order to perform its action on all elements of an
# input array. Note how it composes nicely by juxtaposition.
all() {
    # Args: [Name of Array to compare from: String] [Expression] [Name of array to compare against: String]
    local -n array1="$1"
    local expression="$2"
    local -n array2="$3"

    for elm in "${array1[@]}"; do
        "$expression" "$elm" array2 || return 1
    done
    return 0

}
test_all_elementInArray() {
    all test1 elementInArray test1 && echo 'should work'
    all test3 elementInArray test1 && echo 'should also work'
    all test6 elementInArray test6 && echo "should also work"
    all test2 elementInArray test1 && echo 'should fail'
    all test4 elementInArray test1 && echo 'should also fail'
    all test1 elementInArray test6 && echo 'should also fail'
}
# and for completeness sake:
any() {
    # Args: Array Expression Array
    local -n array1="$1"
    local expression="$2"
    local -n array2="$3"

    for elm in "${array1[@]}"; do
        "$expression" "$elm" array2 && return 0
    done
    return 1
}

# So it seems our array-and-strings-based life in the shell is good.  We can
# define clean interfaces with minimal responsibility and pass around arrays
# without typing "${...[@]}" all the time. The next example exposes a problem
# with call-by-reference: external commands can't access arrays.

# The following function works when composed with 'simpleElementIn',
# since the values of array2 are actually expanded to the command line. Note, that
# the xargs call uses uses recursive dispatch, as described in
# ./dispatch/recursive_dispatch.sh.
parallelAll() {
    local -n array1="$1"
    local exp="$2"
    local -n array2="$3"

    # echo "${array1[@]}"

    printf '%s\n' "${array1[@]@Q}" | xargs -I {} -P 3 bash "$0" "$exp" "{}" "${array2[@]}"

}
# Btw this works because xargs exits with status 123 if any of the invocations exit with
# status 1-125. If you wonder what is happening before the pipe operator, please be
# patient, we'll get to it.

test_parallelAll() {
    parallelAll test1 simpleElementIn test1 && echo "should work"
    parallelAll test3 simpleElementIn test1 && echo "should also work"
    parallelAll test6 simpleElementIn test6 && echo "should also work"
    parallelAll test2 simpleElementIn test1 && echo "should fail"
    parallelAll test4 simpleElementIn test1 && echo "should also fail"
    parallelAll test1 simpleElementIn test6 && echo "should also fail"
}

# Here's the same thing but with passing the array by reference
parallelAllWithArrays() {
    local -n array1="$1"
    local exp="$2"
    local -n array2="$3"

    # echo "${array1[@]}"

    printf '%s\n' "${array1[@]@Q}" | xargs -t -I {} -P 3 bash "$0" "$exp" "{}" array2

}

test_parallelWithArrays() {
    # none of these work
    parallelAllWithArrays test1 elementInArray test1 && echo "should work"
    parallelAllWithArrays test3 elementInArray test1 && echo "should also work"
    parallelAllWithArrays test2 elementInArray test1 && echo "should fail"
    parallelAllWithArrays test4 elementInArray test1 && echo "should also fail"
    # this just does not work
}

# So here we have found a peculiar discrepancy: We can compose array-based functions
# inside of the script's scope nicely but we can't pass arrays _to_ our script.
# All we can do is passing the values, which poses additional overhead to
# ensure compatibility (such as parsing values into arrays again). This is the
# perfect place for bugs to crawl in.

# There is but a loophole: Its in fact possible to pass arrays to functions
# declared in other scripts by 'source'ing them. 'source' can take arguments
# and since it executes the commands in the current shell, variables 'carry
# over'.  By the way, source has some interesting properties. It returns the
# exit status of the command last run in the file.  If we allow recursive
# dispatch in the source target, we can return function values or stdout as
# well.
test_sourceArray() {
    local -a sourcedArray="( $(source ./arrays/toBeSourced.sh arrayFun test1) )"
    declare -p sourcedArray
}
test_sourceTruth() {
    source ./arrays/toBeSourced.sh trueFun
    echo $?

    source ./arrays/toBeSourced.sh falseFun
    echo $?

}

# I guess this goes down even further the rabbit hole of
# esoteric-but-maybe-useful shell aspects. But think about it:  With this
# technique we can create an array-based 'functional core' of scripts than can
# be factored in a sane fashion, which in turn can be directed by an
# 'imperative shell', which acts like any other shell script.

# The earlier examples focused mainly on transforming arrays -which are passed
# by reference- into scalars, like true or false.  Next, lets have a look into
# the state of the union regarding returning arrays and composition in pipes.

# First lets start with a disclaimer:
#
#     BASH DOES NOT ALLOW FOR ARRAYS TO BE RETURNED!
#     ALL THINGS SHOWN HERE ARE MERE HACKS!
#
# Yep, you have been warned. Remember how piping the array into xargs in
# parallelAll involved some transformation with printf and another ominous @?
# This had to be done because the pipe operator forks a subprocess with its own
# stdin and stdout, connecting stdout of the process left of the pipe with
# stdin on the right. The problem is: printing the array to stdout just
# displays the blanks which are used to separate elements of the array. ("a"
# "b" "c") looks just like ("a b" "c") when printed, and this of course can
# cause a lot of trouble when dealing with paths and filenames. This only seem
# to apply to stdout; Notice we didn't have to deal with this in our very first
# example, when passing the array elements as parameters.

# Apart from null-terminating the elements with printf (or some clever IFS
# tricks), we have a few more options, in the form of operators (see man bash
# for more Details). These allow for transformations on the elements before printing:
test_operators() {
    echo "${test6[@]@E}" # produces a b c d
    echo "${test6[@]@Q}" # produces 'a b' 'c d'
    echo "${test6[@]@A}" # produces declare -a test6=([0]="a b" [1]="c d")
    echo "${test6[@]@a}" # produces a a
    echo "${test6[@]@P}" # produces a b c d
    echo "${test6[@]@K}" # produces 0 "a b" 1 "c d"
    echo "${test6[@]@k}" # produces 0 a b 1 c d
}

# @Q seems like a useful transformation for our purpose. We can keep all
# our 'weird' whitespaces and other things while being able to reconstruct
# the array easily. @A is a bit of an oddity (in an already pretty odd bunch).
# It transforms the parameter before it into the respective declare statement.
# We wont use it for now, but I can hear it calling my name!

# Lets use our newly gained knowledge to construct a function which returns an
# array. It could be anything, so lets go with a reimplementation of cat, but for
# arrays:
catArray() {
    # Args: [Names of arrays to concatenate: String...]
    # Returns: [Quoted String of concatenated Array Elements: String]

    # Note the unusual quoting syntax. This is mandatory when constructing
    # arrays from @Q-transformed strings
    local -a params="(${@:-$(</dev/stdin)})"
    for ((i=0; i<"${#params[@]}"; i++)); do
        local -n arr"${i}"="${params[${i}]}"
    done
    local -a out=()
    for ((i=0; i<"${#params[@]}"; i++)); do
        local -n arrayName="arr${i}"
        # declare -p "arr${i}"
        out=("${out[@]}" "${arrayName[@]}")
    done
    echo "${out[@]@Q}"
}
# Here multiple things are happening: Starting with parameter parsing, the first
# block allows reading array names from stdin or positional parameters by
# reference as we are used to by now. The second iteraton is just concatenation
# and in the last line we return the array with the @Q transformation applied.
test_cat() {
    local -a test7=("${test6[@]}" "${test1[@]}")
    [[ $(echo test6 test1 | catArray) == "${test7[@]@Q}" ]] && echo 'should work'
    [[ $(catArray test6 test1) == "${test7[@]@Q}" ]] && echo 'should work'
    [[ $(catArray test6 test1) == $(catArray test7) ]] && echo 'should also work'
}

# Next we may want to parse the @Q-transformed output in some way.
# For example, print it as lines for consumption in pipes:
splitArray() {
    # Args: [Quoted string of array elements: String]
    # Returns: [Newline-separated array elements: String]
    local -a tempArray="( ${@:-$(</dev/stdin)} )"
    # declare -p arr
    printf '%s\n' "${tempArray[@]}"
}

# This is the inverse function to splitarray
unsplitArray() {
    # Args: [Newline-separated array elements: String]
    # Returns [Quoted string of array elements: String]
    local -a tempArray=()
    if [[ $# -gt 0 ]]; then
        readarray -t tempArray < <(echo "$@")
    else
        readarray -t tempArray </dev/stdin
    fi
    # declare -p tempArray
    echo "${tempArray[@]@Q}"
}

test_split() {
    [[ $(splitArray "${test6[@]@Q}") == $(echo "${test6[@]@Q}" | splitArray) ]] && echo 'should work'
    [[ $(catArray test6 test6 | splitArray | sort -u) == $(splitArray "${test6[@]@Q}") ]] && echo 'should work'
    [[ $(catArray test6 | splitArray | unsplitArray) == $(catArray test6) ]] && echo 'should also work'
    [[ $(unsplitArray $'a b\nc d') == $(echo $'a b\nc d' | unsplitArray) ]] && echo 'should also work'
}


source ./dispatch/recursive_dispatch.sh

