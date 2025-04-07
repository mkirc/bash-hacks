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
    local default_val=${TENSOR_DEFAULT_VAL:-0}

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
    # Returns: [Tensor of order-(Initial Dimension-Dim): String]
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

isOrderZero() {
    # Args: [Tensor component: String...]
    # Returns [True if length of component is one, else False: Int]

    # Because of the way makeTensor() constructs a tensor, dimensions with
    # shape 1 will be treated as just one more level of escaping, thus an Array
    # constructed from that will have as many elements as the escaped element,
    # 1 for a tensor order-0 or higher otherwise.
    local -a _tensor="( $(echo "${@}") )"
    [[ "${#_tensor[@]}" -gt 1 ]] && return 1 || return 0
}

test_isOrderZero() {
    isOrderZero $(echo "'a'") && echo 'should work'
    local -a list="( $(makeTensor 2) )"
    # declare -p list
    isOrderZero "${list[@]@Q}" && echo 'should fail'
    local -a matrix="( $(makeTensor 2 2) )"
    # declare -p matrix
    isOrderZero "${matrix[@]@Q}" && echo 'should fail'
    local -a weird_list="( $(makeTensor 1 2) )"
    # declare -p weird_list
    isOrderZero "${weird_list[@]@Q}" && echo 'should also fail'
    local -a weird_matrix="( $(makeTensor 1 2 2) )"
    # declare -p weird_matrix
    isOrderZero "${weird_matrix[@]@Q}" && echo 'should also fail'
}

setTensorComponent() {

    local component_string="$(</dev/stdin)"
    local -n current_tensor="$1"
    shift

    # If the dimension at which the component to insert is equal to the order
    # of the tensor (or in other words, if the component is of order zero) the
    # the other components at this order need to be escaped for proper
    # encoding.
    isOrderZero "$component_string" \
        && local -i component_order=0 \
        || local -i component_order=1

    # record max_idx for dim for later use
    local -a max_idxs=()

    # descend into tensor following the supplied indices, recording unchanged
    # components for reconstruction
    local -i dim max_dim="$#"
    for((dim=1; dim<=$max_dim; dim++)); do
        # get index to follow into for current dimension
        local -i target_idx=${!dim}

        # for all indices per dimension
        local -i idx max_idx=$((${#current_tensor[@]}-1))
        for((idx=0; idx<=$max_idx; idx++)); do
            # case idx!=target_idx: record component string for later use
            [[ $dim -eq $max_dim ]] && [[ $component_order -eq 0 ]] \
                && local tensor_"$dim"_"$idx"="$(echo ${current_tensor[$idx]@Q})" \
                || local tensor_"$dim"_"$idx"="$(echo ${current_tensor[$idx]})"

            # case idx==target_index, dim<max_dim: mark next level for descent
            [[ $idx -eq $target_idx ]] && [[ $dim -lt $max_dim ]] \
                && local -a next_tensor="( $(echo $current_tensor[$idx]) )"

            # case idx==target_idx, dim==max_dim: set supplied component string
            [[ $idx -eq $target_idx ]] && [[ $dim -eq $max_dim ]] \
                && local tensor_"$dim"_"$idx"="$component_string"
        done

        [[ $dim -lt $max_dim ]] \
            && local -a current_tensor="( $(echo ${next_tensor[@]@Q}) )"

        max_idxs+=($max_idx)
    done

    # reconstruct tensor bottom up.
    local -a out_tensor=()
    for((dim=$max_dim; dim>0; dim--)); do
        out_tensor=()

        # for all indices per dimension
        local -i idx max_idx=${max_idxs[$(($dim-1))]}
        for((idx=0; idx<=$max_idx; idx++)); do
            if [[ -v tensor_"$dim"_"$idx" ]]; then
                local tensor_name="tensor_${dim}_${idx}"
                out_tensor+=( "$(echo ${!tensor_name})" )
            fi
        done

        if [[ $dim -gt 1 ]]; then
            local next_dim=$(($dim-1))
            local next_target_idx=${!next_dim}
            local tensor_"$next_dim"_"$next_target_idx"="$(echo ${out_tensor[*]})"
        fi
    done

    echo "${out_tensor[@]@Q}"
}

test_setTensorComponent() {
    TENSOR_DEFAULT_VAL=1
    local -a list="( $(makeTensor 2) )"
    TENSOR_DEFAULT_VAL=0
    local -a matrix="( $(makeTensor 2 2) )"
    declare -p matrix
    local -a out="( $(echo "${list[@]@Q}" | setTensorComponent matrix 1) )"
    declare -p out
    local -a out="( $(echo "'2'" | setTensorComponent out 0 1) )"
    declare -p out
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
