# Part 3: Multidimensional
# Again we begin with a disclaimer: Bash does not support multidimensional
# Arrays. All things presented here are mere hacks!
#
# That said:

getMatrixValue() {
    local -n _matrix="$1"
    shift
    local -i max_level="$#"

    local -a current_matrix="( $(catArray matrix) )"
    local -i level=0  parameter_index=1 matrix_index
    while [[ $level -lt $max_level ]]; do
        # descend into matrix
        matrix_index=${!parameter_index}
        # echo "${current_matrix[$matrix_index]@Q}" | parseOneLevel
        current_matrix=( "$(echo "${current_matrix[$matrix_index]@Q}" | parseOneLevel)" )
        echo "${current_matrix[0]}"
        declare -p current_matrix
        # catArray current_matrix | breakLines
        # return value
        level+=1
        parameter_index+=1
    done
    catArray current_matrix | breakLines
}

parseOneLevel() {
    local -a tempArray="( ${*:-$(</dev/stdin)} )"
    # catArray tempArray
    echo "${tempArray[@]}" | while read line; do
        echo "${line[@]}"
    done
}


constructThreeByThree() {
    local -a row=( 'a a' a a )
    # construct 3x3 matrix
    for i in {0..2}; do
        printf '%s\n' "${row[*]@Q}"
    done
}

makeTensor() {
    local -i i dim="$#"
    local default_val=0
    for(( i=1; i<=$dim; i++ )); do
        local current_dim=${!i}
        local -i j
        local -a current_row=()
        if [[ $i -eq 1 ]]; then
            for((j=0; j<$current_dim; j++)); do
                current_row+=("$default_val")
            done
            local -a current_tensor="( $(echo ${current_row[@]@Q}) )"
        else
            # declare -p current_tensor
            local tensor_string="$(echo ${current_tensor[*]@Q})"
            # local tensor_string=$(printf '%s\n' "${current_tensor[*]@Q}")
            current_tensor=()
            for((j=0; j<$current_dim; j++)); do
                # echo $tensor_string
                current_tensor+=( "$(echo $tensor_string)" )
            done
        fi
    done
    echo "${current_tensor[@]@Q}"
}

test_makeTensor() {
    local -a current_tensor="( $(makeTensor 2 2 2) )"
    declare -p current_tensor
    local -a tensorMin1="( $(echo ${current_tensor[0]}) )"
    declare -p tensorMin1
    local -a tensorMin2="( $(echo ${tensorMin1[0]}) )"
    declare -p tensorMin2

}

test_getMatrixValue() {
    local -a matrix=( "$(constructThreeByThree)" )
    declare -p matrix
    local -a parsedMatrix="( $(catArray matrix | parseOneLevel | joinLines) )"
    declare -p parsedMatrix
    local -a row="( $(echo ${parsedMatrix[0]}) )"
    declare -p row
    local elm=$(echo ${row[0]})
    declare -p elm
    # local -a l1=( "$(catArray matrix | parseOneLevel)" )
    # declare -p l1
    # set -ex
    # getMatrixValue matrix 0 0
    # set +ex
}


gatherAllArrays() {
    # Args: [Name of Array to compare from: String] [Expression]
    # Returns [Quoted string of array elements: String]
    local -n array1="$1"
    local -a out=()
    local elm

    shift

    for elm in "${array1[@]}"; do
        local -a result="( $(${@} ${elm}) )"
        out+=("${result[@]@Q}")
        echo "${result[@]@Q}"
    done
}

test_gatherAllArrays() {
    local -a testA=('a/a' 'a/b/b' 'c')
    local -a outA="$(gatherAllArrays testA splitString '/')"
    local -i i=0
    catArray outA | breakLines | while read line; do
        local -a arr="( ${line} )"
        [[ $(catArray arr) == $( splitString '/' "${testA[$i]}") ]] && echo 'should work'
        i+=1
    done
}

source ./dispatch/recursive_dispatch.sh
