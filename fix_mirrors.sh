#!/bin/bash

set -o errexit
set -o nounset
set -o xtrace

function error() {
    echo 1>&2 "ERROR: $@"
    echo 1>&2
    usage
    exit 1
}

function usage() {
    cat - <<EOF
Usage: ${0#./} [OPTION]...

Options:
    --env <env>
        Environment number - 1 by default
    -h/--help
        Display this help message.
EOF
}

fuel_download_settings(){
	local env="$1"

	fuel settings --download  --env $env
}

fuel_upload_settings(){
	local env="$1"

	fuel settings --upload --env $env
}

fuel_fix_mirrors(){
	local env="$1"

	sed -i 's/archive.ubuntu.com/135.16.118.16/g' settings_${env}.yaml
	sed -i 's@mirror.fuel-infra.org@135.16.118.16/mirantis@g' settings_${env}.yaml
}

fuel_fix_ntp(){
	local env="$1"

	sed -i 's|0.pool.ntp.org, 1.pool.ntp.org, 2.pool.ntp.org|135.38.244.3, 135.38.244.16|g' settings_${env}.yaml
}

function main () {
    local env="1"

    while [[ ${#} -gt 0 ]]; do
        case "${1}" in
            --role)     role="${2}"; shift;;
            --env)      env="${2}"; shift;;
            --config)   config="${2}"; shift;;
            -h|--help)  usage; exit 0;;
            --)         break;;
            -*)         error "Unrecognized option ${1}";;
        esac

    shift
    done

    if [[ -z "${env}" ]]; then  error "Choose environment for deployment";fi
	tmpdir=$(mktemp -d /tmp/XXX)
	pushd $tmpdir
	fuel_download_settings "$env"
	fuel_fix_mirrors "$env"
	fuel_fix_ntp "$env"
	fuel_upload_settings "$env"
	popd
	rm -rf $tmpdir

}

main "$@"
