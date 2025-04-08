source ./arrays/arrays.sh
# Bonus digression 1: Parallel all() and other source'ery.
# The next example exposes a problem with call-by-reference: external processes
# (forked or created otherwise) can't access our array references. The function
# works when composed with 'simpleElementIn', since the values of array2 are
# actually expanded to the command line.

 parallelAllElements() {
    # Args: [Name of Array to act on: String] [Expression: String...] [Name of Array to test against: String]
    # Returns: [True if all calls to Expression evaluated to True, else False: Int]
    local -n array1="$1"
    local exp="$2"
    local -n array2="$3"

    catArray array1 | splitArray | xargs -I {} -P 3 bash "$0" "$exp" "{}" "${array2[@]}"
 }

test_parallelAllElements() {
    parallelAllElements test1 simpleElementIn test1 && echo "should work"
    parallelAllElements test3 simpleElementIn test1 && echo "should also work"
    parallelAllElements test6 simpleElementIn test6 && echo "should also work"
    parallelAllElements test2 simpleElementIn test1 && echo "should fail"
    parallelAllElements test4 simpleElementIn test1 && echo "should also fail"
    parallelAllElements test1 simpleElementIn test6 && echo "should also fail"
}

# This would be the equivalent using named references. This would be quite cool,
# but it fails on local-only references. Run the tests for clarification and think
# about the scope of the referenced arrays.
parallelAll() {
    # Args: [Name of Array to act on: String] [Expression: String...]
    # Returns: [True if all calls to Expression evaluated to True, else False: Int]
    local -n array1="$1"
    shift

    # echo "${array1[@]}"

    catArray array1 | breakLines | xargs -I {} -P 3 bash "$0" "$@" '{}'

}
# Note, that the xargs call uses uses recursive dispatch, as described in
# ./dispatch/recursive_dispatch.sh.

# Btw this works because xargs exits with status 123 if any of the invocations
# exit with status 1-125. If you wonder what is happening left of the pipe
# operator, please be patient, we'll get to it.

test_parallelAll() {

    parallelAll test1 inArray test1 && echo 'should work'
    parallelAll test3 inArray test1 && echo 'should also work'
    parallelAll test6 inArray test6 && echo "should also work"
    parallelAll test2 inArray test1 && echo 'should fail'
    parallelAll test4 inArray test1 && echo 'should also fail'
    parallelAll test1 inArray test6 && echo 'should also fail'
    parallelAll test1 inArray test3 && echo 'should also fail'

    parallelAll test6 not inArray test6 && echo "should fail"
    # none found
    parallelAll test1 not inArray test6 && echo 'should uhm work'
    # some found
    parallelAll test4 not inArray test1 && echo 'should uhm fail'

    local -n testA=test1
    parallelAll test1 inArray testA && echo 'should work' # but fails, can you guess why?

}

# So here we have found a peculiar discrepancy: We can compose array-based functions
# inside of the script's scope nicely but we can't pass arrays _to_ our script.
# All we can do is passing the values, which poses additional overhead to
# ensure compatibility (such as parsing values into arrays again). This is the
# perfect place for bugs to crawl in.
# You may or may not agree that parallelAll looks rather involved. It only
# really works because the test Arrays are global variables in this script
# and are set via recursive dispatch for every forked process. It is much
# slower than all() and surely parsing the whole file only to invoke a
# function is not very efficient. Since inArray is a pure lookup, we don't
# have to think about job control, let's maybe leave it at that and skip the
# imperative functions :)

# We're pretty deep into weird bash stuff already, aren't we? Did you know,
# that it's in fact possible to pass arrays to functions declared in other
# scripts by 'source'ing them? 'source' can take arguments and since it
# executes the commands in the current shell, variables 'carry over'.  By the
# way, source has some interesting properties. It returns the exit status of
# the command last run in the file.  If we allow recursive dispatch in the
# source target, we can return function values or stdout as well.

test_sourceArray() {
    local -ar sourcedArray="( $(source ./arrays/toBeSourced.sh arrayFun test1) )"
    all sourcedArray inArray test1 && echo 'should work'
}
test_sourceTruth() {
    source ./arrays/toBeSourced.sh trueFun && echo 'should work'

    source ./arrays/toBeSourced.sh falseFun && echo 'should fail'

}


# Bonus digression 2: Exporting functions and abusing @A.

# This is something I found noodling around with parallelAll and
# while thinking about the utility of the @A-transformation (if
# you dont know what I'm referring to, take a look at arrays/arrays.sh:
# test_operators();fi). What @A is really useful for, is exporting
# arrays in a global namespace, since bash sadly never supported
# exporting arrays at all (although there are arrays in the Environment,
# like BASH_SOURCE for example). We can make this happen by -again-
# interpreting the output of the @A transform as a command in a
# subshell. The array, which is transformed, is then declared in
# the global namespace and named references will work.
# Another piece in the puzzle is, how do we get our expression
# into the subshell? In parallelAll we expolited recursive
# dispatch on the same file, but we can get there more elegantly:
# We export the function referenced in the expression part with
# yet another obscure feature of bash: The -f flag on export:

parallelAllFun() {
    local -n array1="$1"
    local exp="$2"
    local -n array2="$3"

    export -f "$exp"
    printf '%s\n' "${array1[@]}" | xargs -I {} -P 3 bash -c "$(echo "${array2[@]@A}"); ${exp} ${!array2} '{}'"
}

test_parallelAllFun() {
    parallelAllFun test1 inArray test1 && echo "should work"
    parallelAllFun test3 inArray test1 && echo "should also work"
    parallelAllFun test6 inArray test6 && echo "should also work"
    parallelAllFun test2 inArray test1 && echo "should fail"
    parallelAllFun test4 inArray test1 && echo "should also fail"
    parallelAllFun test1 inArray test6 && echo "should also fail"
}

source ./dispatch/recursive_dispatch.sh
