# Part 3: Multidimensional
# Again we begin with a disclaimer: Bash does not support multidimensional
# Arrays. All things presented here are mere hacks!
#
# That said:

makeTensor() {
    # Args: [Shape of Tensor (row-major order): Int...(Dim)]
    # Returns: [Quoted Array of nested and escaped Arrays: String]
    local -i dim max_dim="$#"

    # Default value to initialize the tensor
    local default_val=0

    # iterate over dimensions
    for(( dim=1; dim<=$max_dim; dim++ )); do
        local current_shape=${!dim}
        local -i idx
        # 1-d case: construct array. This will be used as a 'base' for higher
        # dimensions or returned, if max_dim==1.
        if [[ $dim -eq 1 ]]; then
            local -a current_row=()
            for((idx=0; idx<$current_shape; idx++)); do
                current_row+=("$default_val")
            done
            local -a current_tensor="( $(echo ${current_row[@]@Q}) )"
        else
            # d>1-case: in order to properly escape and nest arrays, they will
            # be interpreted as a single quoted String.
            local tensor_string="$(echo ${current_tensor[*]@Q})"

            # in order to avoid duplication, current_tensor needs to be cleared
            # and filled with properly encoded array representations
            current_tensor=()
            for((idx=0; idx<$current_shape; idx++)); do
                current_tensor+=( "$(echo $tensor_string)" )
            done
        fi
    done
    echo "${current_tensor[@]@Q}"
}

test_makeTensor() {
    local -a current_tensor="( $(makeTensor 3 3) )"
    declare -p current_tensor
    local -a tensorMin1="( $(echo ${current_tensor[0]}) )"
    declare -p tensorMin1
    local -a tensorMin2="( $(echo ${tensorMin1[0]}) )"
    declare -p tensorMin2

    local -a current_tensor="( $(makeTensor 2 2 2) )"
    declare -p current_tensor
    local -a tensorMin1="( $(echo ${current_tensor[0]}) )"
    declare -p tensorMin1
    local -a tensorMin2="( $(echo ${tensorMin1[0]}) )"
    declare -p tensorMin2

}

getTensorComponent() {
    # Args: [Index of desired component (row-major order): Int...(Dim)]
    # Returns: Tensor of order-(Initial Dimension-Dim): String]
    local -a current_tensor="( $(</dev/stdin) )"
    local -i dim max_dim="$#"

    # iteratively unpack nested arrays
    for(( dim=1; dim<=$max_dim; dim++ )); do
        local -i current_index=${!dim}
        local -a current_tensor="( $(echo ${current_tensor[$current_index]}) )"
    done
    echo "${current_tensor[@]@Q}"
}

test_getTensorComponent() {
    local -a twoByTwoByTwo="( $(makeTensor 2 2 2) )"
    declare -p twoByTwoByTwo
    local -a twoByTwo="( $(echo "${twoByTwoByTwo[@]@Q}" | getTensorComponent 0) )"
    declare -p twoByTwo
    local -a two="( $(echo "${twoByTwoByTwo[@]@Q}" | getTensorComponent 0 0) )"
    declare -p two
    local -a two2="( $(echo ${twoByTwo[@]@Q} | getTensorComponent 0) )"
    declare -p two2
    [[ $(echo "${two[@]@Q}") == $(echo "${two2[@]@Q}") ]] && echo 'should work'
    local -a zero="( $(echo "${twoByTwoByTwo[@]@Q}" | getTensorComponent 0 0 0) )"
    declare -p zero
}


# gatherAllArrays() {
#     # Args: [Name of Array to compare from: String] [Expression]
#     # Returns [Quoted string of array elements: String]
#     local -n array1="$1"
#     local -a out=()
#     local elm

#     shift

#     for elm in "${array1[@]}"; do
#         local -a result="( $(${@} ${elm}) )"
#         out+=("${result[@]@Q}")
#         echo "${result[@]@Q}"
#     done
# }

# test_gatherAllArrays() {
#     local -a testA=('a/a' 'a/b/b' 'c')
#     local -a outA="$(gatherAllArrays testA splitString '/')"
#     local -i i=0
#     catArray outA | breakLines | while read line; do
#         local -a arr="( ${line} )"
#         [[ $(catArray arr) == $( splitString '/' "${testA[$i]}") ]] && echo 'should work'
#         i+=1
#     done
# }

source ./dispatch/recursive_dispatch.sh
