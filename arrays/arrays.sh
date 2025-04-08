#!/usr/bin/env bash


# set -x

test1=("a" "b" "c")
test2=("d")
test3=("a" "b")
test4=("a" "d")
test6=("a b" "c d")

# Run the examples herein like: bash arrays/arrays.sh [function name]


# Part 1:
# Picture yourself with the need to check of a string is an element if an
# indexed array in bash. So you phrase this task to a search engine (or worse)
# and the following might come up:

simpleElementIn() {
    # Args: [Element to match: String] [Elements to match against: String...]
    # Returns: [True if element is found, else false: Int]
    local e match="$1"
    shift
    # for without 'in' implicitly iterates over the
    # (shifted) argument list.
    for e; do
        [[ "$e" == "$match" ]] && return 0
    done
    return 1
}

# This works by shifting the input elements by one and iterating over the
# elements left. So we cant pass it an array 'directly' but by supplying its
# values.

test_elementsIn() {
    simpleElementIn 'a' "${test1[@]}" && echo "should work"
    simpleElementIn 'a b' "${test6[@]}" && echo "should also work"
    simpleElementIn 'd' "${test1[@]}" && echo "should fail"
    simpleElementIn 'a' "${test6[@]}" && echo "should also fail"
}

# This is a modified version, using declare's '-n' flag, which allows to pass
# an array by reference. This feels cleaner and requires less typing.
#
inArray() {
    # Args: [Name of array to match: String] [Element to match: String]
    # Returns: [True if element is found, else false: Int]
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
    # Returns: [True if all Elements in first Array were found in Second, else False: Int]
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
    # Returns: [True if all calls to Expression evaluated to True, else False: Int]
    local -n array1="$1"
    local elm
    shift

    for elm in "${array1[@]}"; do
        "$@" "$elm" || return 1
    done
    return 0
}

any() {
    # Args: [Name of Array to act on: String] [Expression: String...]
    # Returns: [True if all calls to Expression evaluated to True, else False: Int]
    local -n array1="$1"
    local elm
    shift

    for elm in "${array1[@]}"; do
        "$@" "$elm" && return 0
    done
    return 1
}

not() {
    if "$@"; then
        return 1
    else
        return 0
    fi
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
# construct a function with side effects:

append() {
    # Args [Name of Array to append to: String] [Element to append: Any]
    # Returns: [True, if append succeeded, else False: Int]
    local -n ref="$1"

    ref+=("$2")
    return $?
}

test_append() {
    local -n testA="( $(catArray test3) )"
    append testA 'c' || echo 'some error during append'
    [[ "${testA[*]}" == "${test1[*]}" ]] && echo 'should work'

    all testA append testA || echo 'some error during append'
    [[ "${testA[*]}" == "${test1[*]} ${test1[*]}" ]] && echo 'should work'
}

# It may not be the the most intellectually satisfying endeavour, but its
# code working as expected, which is nice. We can define some more imperative
# functions which will come in handy for sure.

insertAt() {
    # Args: [Name of Array to insert into: String] [Index to insert after: Int] [Element  to insert: Any]
    # Returns: [Return value of insert operation, 13 if Index > length of Array: Int]
    local -n ref="$1"
    local -i idx="$2"
    local elm="$3"
    local -i len="${#ref[@]}"
    [[ $(($len + 1)) -gt $idx && $idx -ge 0 ]] \
        || { echo "Index (${2}) out of range"; return 13; }

    ref=( "${ref[@]:0:$idx}" "$elm" "${ref[@]:$idx:$len}" )
    return $?
}

test_insertAt() {
    local -a testA="( $(catArray test3) )"
    insertAt testA 3 'c' &>/dev/null && echo 'should fail'
    insertAt testA 2 'c' && [[ "${testA[*]}" == 'a b c' ]] && echo 'should work'
    local -a reversedA=()
    all testA insertAt reversedA 0 && [[ "${reversedA[*]}" == "c b a" ]] && echo 'should work'
}

prependToArray() {
    # Args: [Name of Array to prepend to: String] [Name of Array to prepend: String]
    # Returns: [0 for success, 1 for error in insertAt: Int]
    local -n arrayToPrependTo="$1"
    local -n arrayToPrepend="$2"
    local -i index
    for index in "${!arrayToPrepend[@]}"; do
        # insert reversed array at pos 0
        insertAt arrayToPrependTo 0 "${arrayToPrepend[$((-1-$index))]}" || return 1
    done
    return 0
}

test_prependToArray() {
    local -a testB="( $(catArray test6) )"
    prependToArray testB test1
    [[ "${testB[@]@Q}" == "'a' 'b' 'c' 'a b' 'c d'" ]] && echo 'should work'
}

# So it seems our array-and-strings-based life in the shell is good.  We can
# define clean interfaces with minimal responsibility and pass around arrays
# without typing "${...[@]}" all the time. If you are interested in some
# interesting limitations, head over to arrays/bonus-digressions.sh, Bonus
# digression 1.

# Part2:
# The earlier examples focused mainly on transforming arrays -which are passed
# by reference- into scalars, like true or false.  Next, lets have a look into
# the state of the union regarding returning arrays and composition in pipes.

# First lets start with a disclaimer:
#
#     BASH DOES NOT ALLOW FOR ARRAYS TO BE RETURNED!
#     ALL THINGS SHOWN HERE ARE MERE HACKS!
#
# Yep, you have been warned. Remember how piping the array into xargs in
# parallelAll involved some commands left of the pipe?
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
# won't use it for now, but I can hear it's calling!

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

test_catArray() {
    local -a test7=("${test6[@]}" "${test1[@]}")
    [[ $(echo test6 test1 | catArray) == "${test7[*]@Q}" ]] && echo 'should work'
    [[ $(catArray test6 test1) == "${test7[*]@Q}" ]] && echo 'should work'
    [[ $(catArray test6 test1) == $(catArray test7) ]] && echo 'should also work'
}

# Next we may want to parse the @Q-transformed output in some way.  For
# example, print it as lines for consumption in pipes:
breakLines() {
    # Args: [Quoted string of array elements: String]
    # Returns: [Newline-separated array elements: String]
    local -ar tempArray="( ${*:-$(</dev/stdin)} )"
    # declare -p arr
    printf '%s\n' "${tempArray[@]}"
}

# This is the inverse function to breakLines
joinLines() {
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

test_breakLines() {
    [[ $(breakLines "${test6[@]@Q}") == $(echo "${test6[@]@Q}" | breakLines) ]] && echo 'should work'
    [[ $(catArray test6 test6 | breakLines | sort -u | joinLines) == $(catArray test6) ]] && echo 'should work'
    [[ $(catArray test6 | breakLines | joinLines) == $(catArray test6) ]] && echo 'should also work'
    [[ $(joinLines $'a b\nc d') == $(echo $'a b\nc d' | joinLines) ]] && echo 'should also work'
    local -a testA=("./*")
    catArray testA | breakLines
    breakLines './*' # huh, this expands the glob?!
}

stripPrefix() {
    # Args: [Name of Array to strip: String] [Separator String according toBash Glob Notation: String]
    # Returns [Quoted string of stripped array elements: String]
    local sep="$1"
    shift
    local -a tempArray="( ${*:-$(</dev/stdin)} )"
    local -i idx

    for idx in "${!tempArray[@]}"; do
        tempArray[$idx]="${tempArray[$idx]##$sep}" || return 1
    done
    echo "${tempArray[@]@Q}"
}

stripSuffix() {
    # Args: [Name of Array to strip: String] [Separator String according toBash Glob Notation: String]
    # Returns [Quoted string of stripped array elements: String]
    local sep="$1"
    shift
    local -a tempArray="( ${*:-$(</dev/stdin)} )"
    local -i idx

    for idx in "${!tempArray[@]}"; do
        tempArray[$idx]="${tempArray[$idx]%%$sep}" || return 1
    done
    echo "${tempArray[@]@Q}"
}

test_stripArray() {
    local -a testA=('a/a' 'a/b/b' 'c')
    local -a testB=('a ' 'b c' 'c')
    [[ $(catArray testA | stripPrefix '*/') == $(stripPrefix '*/' "${testA[@]@Q}") ]] && echo 'should work'
    [[ $(catArray testB | stripSuffix ' *') == $(catArray test1) ]] && echo 'should work'
    [[ $(catArray testA | stripPrefix '*/') == $(catArray test1) ]] && echo 'should work'
}

splitString() {
    # Args: [Token on which to split: String] [String to split: String]
    # Returns: [Quoted String of Array Elements: String]
    local token="$1"
    shift
    local string="${*:-$(</dev/stdin)}"
    local -a out=(${string//$token/ })
    echo "${out[@]@Q}"
}

test_splitString() {
    local testString1="the quick fox jumps over the lazy dog."
    [[ $(splitString ' ' "$testString1") == "'the' 'quick' 'fox' 'jumps' 'over' 'the' 'lazy' 'dog.'" ]] && echo 'should work'
    [[ $(splitString ' ' "$testString1") == $(echo "$testString1" | splitString ' ') ]] && echo 'should work'
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
gatherAll() {
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

test_gatherAll() {
    [[ $(gatherAll test3 inArray test1) == $(catArray test3) ]] && echo "should work"
    [[ $(gatherAll test1 inArray test1) == $(catArray test1) ]] && echo "should work"
    [[ $(gatherAll test1 inArray test3) == $(catArray test3) ]] && echo "should work"
    [[ $(gatherAll test4 inArray test1) == "'a'" ]] && echo 'should work'
    [[ $(gatherAll test4 not inArray test1) == "'d'" ]] && echo 'should work'
    [[ $(gatherAll test1 not inArray test1) == "" ]] && echo 'should work'
}

# at this point we can mix and match approaches as needed. For example
# this function returning a reversed copy of the input array uses
# the composibility of 'all':

reversed() {
    # Args: [Name of Array to reverse: String]
    # Returns: [Quoted Array with elements from input in reverse order: String]
    local -a out=()
    all "$1" insertAt out 0
    echo "${out[@]@Q}"
}

test_reversed() {
    local -a reversed6="( $(reversed test6) )"
    [[ "${reversed6[*]@Q}" == "'c d' 'a b'" ]] && echo 'should work'
    [[ $(reversed reversed6) == "${test6[*]@Q}" ]] && echo 'should also work'
}

# or we may even compose more complicated functions:

zipped() {
    # Args: [Name of Array take the even positions: String] [Name of Array to take the odd positions: String]
    # Returns: [Quoted Array, containing zipped values of inputs: String]
    local -n arrayEven="$1"
    local -n arrayOdd="$2"
    [[ "${#arrayOdd[@]}" == "${#arrayEven[@]}" ]] \
        || { echo 'Arrays are not same length, aborting'; return 12; }

    local -a out=()
    local -i index
    for index in $(getKeys arrayEven); do
        insertAt out $(($index*2)) "${arrayEven[$index]}"
        insertAt out $(($index*2+1)) "${arrayOdd[$index]}"
    done
    echo "${out[@]@Q}"
}

# ah, btw:
getKeys() {
    # Args: [Name of Array: String]
    # Returns: String of Keys for Array: String|Int]
    local -n ref="$1"
    echo "${!ref[@]}"
}

test_zipped() {
    local -a testB=(1 2 3)
    local -a zippedTest="( $(zipped test1 testB) )"
    [[ "${zippedTest[*]}" == 'a 1 b 2 c 3' ]] && echo 'should work'
    zipped test1 test3 &>/dev/null && echo 'should fail'
}


source ./dispatch/recursive_dispatch.sh

