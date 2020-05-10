#!/bin/bash

error() {
	>&2 echo "$0: There are errors."
	exit 1
}

if [[ -z $_Dbg_DEBUGGER_LEVEL ]]; then
	trap error ERR
fi

#----------------------------------------------------------------------------------------------

if [[ $1 == --help || $1 == help ]]; then
	cat <<-END
		Generate RedisGears distribution packages.
	
		[ARGVARS...] pack.sh [--help|help] [<module-so-path>]
		
		Argument variables:
		VERBOSE=1     Print commands
		IGNERR=1      Do not abort on error
		
		RAMP=1        Generate RAMP package
		DEPS=1        Generate dependency packages
		RELEASE=1     Generate "release" packages (artifacts/release/)
		SNAPSHOT=1    Generate "shapshot" packages (artifacts/snapshot/)
		JUST_PRINT=1  Only print package names, do not generate

		VARIANT=name        Build variant (empty for standard packages)
		BRANCH=name         Branch name for snapshot packages
		GITSHA=1            Append Git SHA to shapshot package names
		CPYTHON_PREFIX=dir  Python install dir

	END
	exit 0
fi

#----------------------------------------------------------------------------------------------

RAMP=${RAMP:-1}
DEPS=${DEPS:-1}

RELEASE=${RELEASE:-1}
SNAPSHOT=${SNAPSHOT:-1}

[[ $VERBOSE == 1 ]] && set -x
[[ $IGNERR == 1 ]] || set -e

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
ROOT=$HERE
. $HERE/deps/readies/shibumi/functions

ARCH=$(./deps/readies/bin/platform --arch)
OS=$(./deps/readies/bin/platform --os)
OSNICK=$(./deps/readies/bin/platform --osnick)

#----------------------------------------------------------------------------------------------

pack() {
	# artifact=release|snapshot
	local artifact="$1"
	local pack_fname="$2"

	cd $ROOT
	local ramp="$(command -v python) -m RAMP.ramp" 
	local packfile=artifacts/$artifact/$pack_fname
	./deps/readies/bin/xtx -d GEARS_PYTHON3_NAME=python3_$SEMVER -d GEARS_PYTHON3_FNAME=$URL_FNAME -d GEARS_PYTHON3_SHA256=$(cat $DEPS.sha256) ramp.yml > /tmp/ramp.yml
	# local packname=$(GEARS_NO_DEPS=1 $ramp pack -m /tmp/ramp.yml -o $packfile $GEARS_SO 2> /tmp/ramp.err | tail -1)
	rm -f /tmp/ramp.fname
	GEARS_NO_DEPS=1 $ramp pack -m /tmp/ramp.yml --packname-file /tmp/ramp.fname --verbose --debug -o $packfile $GEARS_SO >/tmp/ramp.err 2>&1 || true

	if [[ ! -f /tmp/ramp.fname ]]; then
		>&2 echo Failed to pack $artifact
		cat /tmp/ramp.err >&2
		exit 1
	else
		local packname=`cat /tmp/ramp.fname`
	fi

	echo "Created artifacts/$artifact/$packname"
}

#----------------------------------------------------------------------------------------------

pack_deps() {
	CPYTHON_PREFIX=${CPYTHON_PREFIX:-/var/opt/redislabs/lib/modules/python3}
	if [[ -z $CPYTHON_PREFIX ]]; then
		>&2 echo "$0: $CPYTHON_PREFIX is not defined"
		exit 1
	fi
	if [[ ! -d $CPYTHON_PREFIX ]]; then
		>&2 echo "$0: $CPYTHON_PREFIX does not exist"
		exit 1
	fi

	local TAR=artifacts/release/$RELEASE_deps
	TAR_PATH=$(realpath $TAR)
	cd $CPYTHON_PREFIX
	# find . -name __pycache__ -type d -exec rm -rf {} \; 2>> /dev/null || true
	export SEMVER
	{ tar -c --sort=name --owner=root:0 --group=root:0 --mtime='UTC 1970-01-01' --transform "s,^./,python3_$SEMVER/," ./ 2>> /tmp/pack.err | gzip -n - > $TAR_PATH ; E=$?; } || true
	[[ $E != 0 ]] && cat /tmp/pack.err; $(exit $E)
	cd - > /dev/null
	sha256sum $TAR | gawk '{print $1}' > $TAR.sha256
	echo "Created $TAR"

	local TAR1=artifacts/snapshot/$SNAPSHOT_deps
	cp $TAR $TAR1
	cp $TAR.sha256 $TAR1.sha256
	# ( cd artifacts/snapshot; ln -sf ../../$TAR $TAR1; ln -sf ../../$TAR.sha256 $TAR1.sha256; )
	echo "Created $TAR1"
}

#----------------------------------------------------------------------------------------------

# export ROOT=`git rev-parse --show-toplevel`
export ROOT=$(realpath $HERE)

PACKAGE_NAME=${PACKAGE_NAME:-redisgears}

[[ -z $BRANCH ]] && BRANCH=${CIRCLE_BRANCH:-`git rev-parse --abbrev-ref HEAD`}
BRANCH=${BRANCH//[^A-Za-z0-9._-]/_}
if [[ $GITSHA == 1 ]]; then
	GIT_COMMIT=$(git describe --always --abbrev=7 --dirty="+" 2>/dev/null || git rev-parse --short HEAD)
	BRANCH="${BRANCH}-${GIT_COMMIT}"
fi

export PYTHONWARNINGS=ignore

cd $ROOT

NUMVER=$(NUMERIC=1 $ROOT/getver)
SEMVER=$($ROOT/getver)

if [[ ! -z $VARIANT ]]; then
	VARIANT=-${VARIANT}
fi
RELEASE_ramp=${PACKAGE_NAME}.$OS-$OSNICK-$ARCH.$SEMVER${VARIANT}.zip
SNAPSHOT_ramp=${PACKAGE_NAME}.$OS-$OSNICK-$ARCH.${BRANCH}${VARIANT}.zip
RELEASE_deps=${PACKAGE_NAME}-dependencies.$OS-$OSNICK-$ARCH.$SEMVER.tgz
SNAPSHOT_deps=${PACKAGE_NAME}-dependencies.$OS-$OSNICK-$ARCH.$BRANCH.tgz

if [[ $JUST_PRINT == 1 ]]; then
	if [[ $RAMP == 1 ]]; then
		[[ $RELEASE == 1 ]] && echo $RELEASE_ramp
		[[ $SNAPSHOT == 1 ]] && echo $SNAPSHOT_ramp
	fi
	if [[ $DEPS == 1 ]]; then
		[[ $RELEASE == 1 ]] && echo $RELEASE_deps
		[[ $SNAPSHOT == 1 ]] && echo $SNAPSHOT_deps
	fi
	exit 0
fi

mkdir -p artifacts/snapshot artifacts/release

if [[ $RAMP == 1 ]]; then
	if ! command -v redis-server > /dev/null; then
		>&2 echo "$0: Cannot find redis-server. Aborting."
		exit 1
	fi

	[[ -z $1 ]] && >&2 echo "$0: Nothing to pack. Aborting." && exit 1
	[[ ! -f $1 ]] && >&2 echo "$0: $1 does not exist. Aborting." && exit 1
	
	RELEASE_SO=$(realpath $1)
	SNAPSHOT_SO=$(dirname $RELEASE_SO)/snapshot/$(basename $RELEASE_SO)
fi

if [[ $DEPS == 1 ]]; then
	pack_deps
fi

if [[ $RAMP == 1 ]]; then
	GEARS_SO=$RELEASE_SO DEPS=artifacts/release/$RELEASE_deps URL_FNAME=$RELEASE_deps pack release "$RELEASE_ramp"
	GEARS_SO=$SNAPSHOT_SO DEPS=artifacts/snapshot/$SNAPSHOT_deps URL_FNAME=snapshots/$SNAPSHOT_deps pack snapshot "$SNAPSHOT_ramp"
fi
