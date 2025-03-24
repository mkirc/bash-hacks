
arrayFun() {
    local -n array1="$1"
    echo "${array1[@]}"
}

trueFun() {
    return 0
}

falseFun() {
    return 1
}

source ./dispatch/recursive_dispatch.sh
