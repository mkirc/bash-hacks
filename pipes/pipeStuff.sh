

test1=("a" "b" "c")
test2=("d")
test3=("a" "b")
test4=("a" "d")
test5=("a" "a" "a")
test6=("a b" "c d")

# accepts exactly one input parameter
# via pipe or as positional argument.
arrayPipe() {
    # Args: [Arrayname to perform actions on]:String
    local -n array1="${1:-$(</dev/stdin)}"
    IFS='\0'
    array1=("${array1[@]}" "+1")
    echo "${array1[*]}"
}

splitArray() {
    # Args: [Arrayname to perform actions on]:String
    # assume input as null separated array string
    local -a arrayToPrint
    oldIFS="$IFS"
    IFS='\0'
    arrayToPrint=( ${1:-$(</dev/stdin)} )
    IFS="$oldIFS"
    # declare -p array1
    printf '%s\n' "${arrayToPrint[@]}"
}

printArray() {
    # Args: [Arrayname to perform actions on]:String
    # assume input as null separated array string
    local -a arrayToPrint
    oldIFS="$IFS"
    IFS='\0'
    arrayToPrint=( ${1:-$(</dev/stdin)} )
    IFS="$oldIFS"
    # declare -p array1
    echo "${arrayToPrint[@]}"
}

# Piping names to functions 
test_arrayPipe() {
    echo test6 | arrayPipe | splitArray
    arrayPipe test6 | splitArray

}

# Accepts one or more input parameters
# via pipe or as positional arguments.
concat() {
    # Args: [Arraynames to perform Action on]:String
    local params=(${*:-$(</dev/stdin)})
    for ((i=0; i<"${#params[@]}"; i++)); do
        local -n arr"${i}"="${params[${i}]}"
    done
    IFS='\0'
    local -a out=()
    for ((i=0; i<"${#params[@]}"; i++)); do
        local -n arrayName="arr${i}"
        # declare -p "arr${i}"
        out=("${out[@]}" "${arrayName[@]}")
    done
    # printf '%s\n' "${out[@]}"
    echo "${out[*]}"
}

test_multiArrayPipe() {
    local -a test7=("${test6[@]}" "${test1[@]}")
    [[ $(echo test6 test1 | concat | printArray) == "${test7[@]}" ]] && echo 'should work'
    [[ $(concat test6 test1 | printArray) == "${test7[@]}" ]] && echo 'should also work'
    [[ $(concat test1 test1 | splitArray | sort -u ) == $(concat test1 | splitArray) ]] && echo 'Piping to sort also works'
}


source ./dispatch/recursive_dispatch.sh
