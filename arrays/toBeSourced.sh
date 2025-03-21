
arrayFun() {
    local -n array1="$1"
    echo "${array1[@]}"
}

source ./dispatch/recursive_dispatch.sh
