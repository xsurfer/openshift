#!/bin/bash

set -x
echo "sono in abstract/info/bin/deploy_git_dir.sh"

#
# Archive files from a git module to another directory including the git
# submodules if present
#
function print_help {
    echo "Usage: $0 src_dir dest_dir"
    exit 1
}

[ $# -eq 2 ] || print_help

src_dir="$1"
dest_dir="$2"

function extract_submodules {
    # if GIT_DIR is set we need to unset it
    [ ! -z "${GIT_DIR+xxx}" ] && unset GIT_DIR

    # expload tree into a tmp dir
    tmp_dir=${OPENSHIFT_GEAR_DIR}/tmp
    [ -e ${tmp_dir} ] || mkdir ${tmp_dir}
    submodule_tmp_dir=${tmp_dir}/submodules
    pushd ${tmp_dir}

    [ -e ${submodule_tmp_dir} ] && rm -rf ${submodule_tmp_dir}
    git clone ${full_src_dir} submodules

    cd ${submodule_tmp_dir}

    # initialize submodules and pull down source
    git submodule init
    git submodule update

    # archive and copy the submodules
    git submodule foreach "git archive --format=tar HEAD | (cd ${dest_dir}/\${path} && tar --warning=no-timestamp -xf -)"
    popd
    rm -rf ${submodule_tmp_dir}
}

pushd ${src_dir}
full_src_dir=`pwd`

# archive and copy the main module
git archive --format=tar HEAD | (cd ${dest_dir} && tar --warning=no-timestamp -xf -)

# if a .gitmodules file exists we need to expload the whole tree and extract
# the submoules
[ -f ${dest_dir}/.gitmodules ] && extract_submodules

popd
