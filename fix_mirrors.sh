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

fuel_enable_public_int(){
	local env="$1"

	python << EOF
import yaml

with open("settings_${env}.yaml","r") as f_in:
  settings=yaml.load(f_in)
  settings["editable"]["public_network_assignment"]["assign_to_all_nodes"]["value"]=True
with open("settings_${env}.yaml", "w") as f_out:
  f_out.write(yaml.dump(settings, default_flow_style=False))
EOF
}

fuel_add_mirror(){
	local env="$1"
	local name="$2"
	local priority="$3"
	local section="$4"
	local _type="$5"
	local suite="$6"
	local url="$7"


	python << EOF
import yaml
repo={"name":     "$name",
      "priority": $priority,
      "section":  "$section",
      "type":  "$_type",
      "suite": "$suite",
       "uri": "$url"}

with open("settings_${env}.yaml","r") as f_in:
  settings=yaml.load(f_in)
  settings["editable"]["repo_setup"]["repos"]["value"].append(repo)
with open("settings_${env}.yaml", "w") as f_out:
  f_out.write(yaml.dump(settings, default_flow_style=False))
EOF
}

fuel_allow_noncontroller_deployment(){
	dockerctl shell nailgun grep  '#cls._check_controllers_count'  /usr/lib/python2.6/site-packages/nailgun/task/task.py || {
	dockerctl shell nailgun sed -e "s/cls._check_controllers_count/#cls._check_controllers_count/g" -i /usr/lib/python2.6/site-packages/nailgun/task/task.py;
	dockerctl shell nailgun supervisorctl restart nailgun;}
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
	fuel_allow_noncontroller_deployment
	fuel_download_settings "$env"
	fuel_fix_mirrors "$env"
	fuel_fix_ntp "$env"
	fuel_enable_public_int "$env"
	fuel_add_mirror "$env" "percona" "1200" "main" "deb" "trusty" "http://135.16.118.16/percona/"
	fuel_upload_settings "$env"
	popd
	rm -rf $tmpdir

}

main "$@"
