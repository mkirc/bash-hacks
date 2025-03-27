#!/usr/bin/env bash


# set -x

test1=("a" "b" "c")
test2=("d")
test3=("a" "b")
test4=("a" "d")
test6=("a b" "c d")

# Run the examples herein like: bash arrays/arrayStuff.sh [function name]

# Picture yourself with the need to check of a string is an element if an
# indexed array in bash. So you phrase this task to a search engine (or worse)
# and the following might come up:

# This works by shifting the input elements by one and iterating over the
# elements left. So we cant pass it an array 'directly' but by supplying its
# values.
simpleElementIn() {
    # Args: [Element to match: String] [Elements to match against: String...]
    # Returns: [True if element is found, else false: Bool]
    local e match="$1"
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

# This is a modified version, using declare's '-n' flag, which allows to pass
# an array by reference. This feels cleaner and requires less typing.
inArray() {
    # Args: [Name of array to match: String] [Element to match: String]
    # Returns: [True if element is found, else false: Bool]
    local -n arrayToMatch="$1"
    local match="$2"
    local elm

    # echo "$match"
    for elm in "${arrayToMatch[@]}"; do
        [[ "$elm" == "$match" ]] && return 0
     done
    return 1
}

test_inArray() {
    inArray test1 'a' && echo 'should work'
    inArray test6 'a b' && echo 'should also work'
    inArray test1 'd' && echo 'should fail'
    inArray test6 'a' && echo 'should also fail'
}

# Nice. So next we may want a function which can test for all elements of
# another array (lets call it array1), if its elements are element of another
# array (lets call that array2)

# A simple solution would be to just iterate over array1 and apply 'inArray' to
# its elements and array2...
allElementsIn() {
    # Args: [Name of Array to compare from: String] [Name of array to compare against: String]
    # Returns: [True if all Elements in first Array were found in Second, else False: Bool]
    local -n array1="$1"
    local -n array2="$2"
    local elm

    for elm in "${array1[@]}"; do
        inArray "$elm" array2 || return 1
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
# by just passing its name.

# This function can take an expression, which itself can be anything acting on
# a number of parameters and a single element, in order to perform its action
# on all elements of an input array. Note how it composes nicely by
# juxtaposition.
all() {
    # Args: [Name of Array to act on: String] [Expression: String...]
    # Returns: [True if all calls to Expression evaluated to True, else False: Bool]
    local -n array1="$1"
    local elm
    shift

    for elm in "${array1[@]}"; do
        "$@" "$elm" || return 1
    done
    return 0
}

# this is an example of another expression which can be composed in that way:
not() {
    if "$@"; then
        return 1
    else
        return 0
    fi
}

# and for completeness sake:
any() {
    # Args: [Name of Array to act on: String] [Expression: String...]
    # Returns: [True if all calls to Expression evaluated to True, else False: Bool]
    local -n array1="$1"
    local elm
    shift

    for elm in "${array1[@]}"; do
        "$@" "$elm" && return 0
    done
    return 1
}


test_all_inArray() {
    all test1 inArray test1 && echo 'should work'
    all test3 inArray test1 && echo 'should also work'
    all test6 inArray test6 && echo "should also work"
    all test2 inArray test1 && echo 'should fail'
    all test4 inArray test1 && echo 'should also fail'
    all test1 inArray test6 && echo 'should also fail'
    all test1 inArray test3 && echo 'should also fail'

    # none found
    all test1 not inArray test6 && echo 'should uhm work'
    # some found
    all test4 not inArray test1 && echo 'should uhm fail'

    any test1 not inArray test3 && echo 'should work'
    any test3 not inArray test1 && echo 'should fail'

    all test1 not inArray test1 && echo 'should fail'
    all test6 not inArray test6 && echo "should also fail"

    # these reduce to 'all ... || echo ...'
    # not all test4 inArray test1 && echo 'should uhm also work'
    # not all test1 inArray test6 && echo 'should uhm also work'
}

# inArray is a pure function. Let's see what happens when we
# construct a fucntion with side effects:

append() {
    # Args [Name of Array to append to: String] [Element to append: String]
    # Returns: [True, if append succeeded, else False: Bool]
    local -n ref="$1"
    local elm="$2"

    ref+=("$2")
    return $?
}

test_append() {
    local -n testA=test3
    append testA 'c'
    [[ "${testA[*]}" == "${test1[*]}" ]] && echo 'should work'

    all testA append testA
    [[ "${testA[*]}" == "${test1[*]} ${test1[*]}" ]] && echo 'should work'
}

# It may not be the the most intellectually satisfying endeavour, but its
# code working as expected, which is nice.

# So it seems our array-and-strings-based life in the shell is good.  We can
# define clean interfaces with minimal responsibility and pass around arrays
# without typing "${...[@]}" all the time. The next example exposes a problem
# with call-by-reference: external processes (forked or created otherwise)
# can't access our array references.

# The following function works when composed with 'simpleElementIn', since the
# values of array2 are actually expanded to the command line. Note, that the
# xargs call uses uses recursive dispatch, as described in
# ./dispatch/recursive_dispatch.sh.
parallelAll() {
    local -n array1="$1"
    local exp="$2"
    local -n array2="$3"

    # echo "${array1[@]}"

    printf '%s\n' "${array1[@]@Q}" | xargs -I {} -P 3 bash "$0" "$exp" "{}" "${array2[@]}"

}

# Btw this works because xargs exits with status 123 if any of the invocations
# exit with status 1-125. If you wonder what is happening before the pipe
# operator, please be patient, we'll get to it.

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
    shift

    # echo "${array1[@]}"

    printf '%s\n' "${array1[@]@Q}" | xargs -t -I {} -P 3 bash "$0" "$exp" "$@" "{}"

}

test_parallelWithArrays() {
    echo 'xargs -t prints input line'
    # none of these work
    parallelAllWithArrays test1 inArray test1 && echo "should work"
    parallelAllWithArrays test3 inArray test1 && echo "should also work"
    parallelAllWithArrays test2 inArray test1 && echo "should fail"
    parallelAllWithArrays test4 inArray test1 && echo "should also fail"
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
    local -ar sourcedArray="( $(source ./arrays/toBeSourced.sh arrayFun test1) )"
    all sourcedArray inArray test1 && echo 'should work'
}
test_sourceTruth() {
    source ./arrays/toBeSourced.sh trueFun && echo 'should work'

    source ./arrays/toBeSourced.sh falseFun && echo 'should fail'

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
# tricks), we have a few more options, in the form of parameter - operators
# (see man bash for more Details). These allow for transformations on the
# elements before printing:
test_operators() {
    echo "${test6[@]@E}" # produces a b c d
    echo "${test6[@]@Q}" # produces 'a b' 'c d'
    echo "${test6[@]@A}" # produces declare -a test6=([0]="a b" [1]="c d")
    echo "${test6[@]@a}" # produces a a
    echo "${test6[@]@P}" # produces a b c d
    echo "${test6[@]@K}" # produces 0 "a b" 1 "c d"
    echo "${test6[@]@k}" # produces 0 a b 1 c d
}

# @Q seems like a useful transformation for our purpose. We can keep all our
# 'weird' whitespaces and other things while being able to reconstruct the
# array easily. @A is a bit of an oddity (in an already pretty odd bunch).  It
# transforms the parameter before it into the respective declare statement.  We
# wont use it for now, but I can hear it's calling!

# Lets use our newly gained knowledge to construct a function which returns an
# array. It could be anything, but let's go with something useful, like a
# reimplementation of cat, but for arrays:
catArray() {
    # Args: [Names of arrays to concatenate: String...]
    # Returns: [Quoted String of concatenated Array Elements: String]

    # Note the unusual quoting syntax. This is mandatory when constructing
    # arrays from @Q-transformed strings
    local -a params="(${*:-$(</dev/stdin)})"
    local i
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

# Here multiple things are happening: Starting with parameter parsing, the
# first block allows reading array names from stdin or positional parameters by
# reference as we are used to by now. The second iteraton is just concatenation
# and in the last line we return the array with the @Q transformation applied.

test_cat() {
    local -a test7=("${test6[@]}" "${test1[@]}")
    [[ $(echo test6 test1 | catArray) == "${test7[*]@Q}" ]] && echo 'should work'
    [[ $(catArray test6 test1) == "${test7[*]@Q}" ]] && echo 'should work'
    [[ $(catArray test6 test1) == $(catArray test7) ]] && echo 'should also work'
}

# Next we may want to parse the @Q-transformed output in some way.  For
# example, print it as lines for consumption in pipes:
splitArray() {
    # Args: [Quoted string of array elements: String]
    # Returns: [Newline-separated array elements: String]
    local -ar tempArray="( ${*:-$(</dev/stdin)} )"
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
    [[ $(catArray test6 test6 | splitArray | sort -u | unsplitArray) == $(catArray test6) ]] && echo 'should work'
    [[ $(catArray test6 | splitArray | unsplitArray) == $(catArray test6) ]] && echo 'should also work'
    [[ $(unsplitArray $'a b\nc d') == $(echo $'a b\nc d' | unsplitArray) ]] && echo 'should also work'
}

# ok, now we have a way to return arrays and manipulate them...but in the
# process we moved away from the original goal: Not to type "${...[@]}" all the
# time. Now in order to create a 'portable' array, we even need two characters
# more! catArray is a bit of a rescue there but still now there is a two-class
# society of arrays: Those which can be referenced by name, and those which are
# returned in a consumable way. Of course we can convert between those, but
# it's something to keep in mind.

# Lets see if at least we can get some of the composibility back. For example
# we may want all Elements of one Array which satisfy an expression acting on
# them.
gather() {
    # Args: [Name of Array to compare from: String] [Expression]
    # Returns [Quoted string of array elements: String]
    local -n array1="$1"
    local -a out=()
    local elm

    shift

    for elm in "${array1[@]}"; do
        if "$@" "$elm"; then
            out+=("$elm")
        fi
    done
    echo "${out[@]@Q}"
}

test_gather() {
    [[ $(gather test3 inArray test1) == $(catArray test3) ]] && echo "should work"
    [[ $(gather test1 inArray test1) == $(catArray test1) ]] && echo "should work"
    [[ $(gather test1 inArray test3) == $(catArray test3) ]] && echo "should work"
    [[ $(gather test4 inArray test1) == "'a'" ]] && echo 'should work'
    [[ $(gather test4 not inArray test1) == "'d'" ]] && echo 'should work'
    [[ $(gather test1 not inArray test1) == "" ]] && echo 'should work'
}


source ./dispatch/recursive_dispatch.sh

