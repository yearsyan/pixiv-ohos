#!/bin/sh
set -eu
PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
DEVECO_ROOT=${DEVECO_ROOT:-/Applications/DevEco-Studio.app/Contents}
export NODE_HOME="$DEVECO_ROOT/tools/node"
export JAVA_HOME="$DEVECO_ROOT/jbr/Contents/Home"
export DEVECO_SDK_HOME="$DEVECO_ROOT/sdk"
export PATH="$NODE_HOME/bin:$DEVECO_ROOT/tools/ohpm/bin:$PATH"
cd "$PROJECT_DIR"
if [ ! -f build-profile.json5 ]; then
  cp build-profile.example.json5 build-profile.json5
  echo 'Created local build-profile.json5. Configure signing in DevEco Studio to install on a device.'
fi
exec "$DEVECO_ROOT/tools/hvigor/bin/hvigorw" --mode module -p product=default -p "module=entry@${HARMONY_TARGET:-default}" -p buildMode=debug assembleHap --no-daemon "$@"
