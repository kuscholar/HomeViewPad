#!/bin/sh
set -eu
: "${1:?Usage: scripts/test.sh SIMULATOR_UUID [full|ci|network|release]}"
simulator=$1
mode=${2:-full}
project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
case "$mode" in
  full|ci|network|release) ;;
  *) printf 'Unknown test mode: %s\n' "$mode" >&2; exit 2 ;;
esac
if [ -n "${RESULT_BUNDLE_PATH:-}" ]; then
  result_dir=$RESULT_BUNDLE_PATH
else
  result_dir=$(mktemp -d "${TMPDIR:-/tmp}/HomePad-tests.XXXXXX")/Tests.xcresult
fi
trap 'printf "Results (%s): %s\n" "$mode" "$result_dir"' EXIT
set --
# These checks require third-party network services. Keep them explicit and runnable.
for method in testDebugWeatherProviderSwitchAndPersistence testWeatherCitySearchPersistenceAndServiceState testLocationPermissionUsesDetectedCity; do
  case "$mode" in
    ci) set -- "$@" "-skip-testing:HomePadUITests/HomePadUITests/$method" ;;
    network) set -- "$@" "-only-testing:HomePadUITests/HomePadUITests/$method" ;;
  esac
done
if [ "$mode" = release ]; then
  set -- -configuration Release -only-testing:HomePadTests/WeatherTests
fi
xcodebuild -project "$project_dir/HomePad.xcodeproj" -scheme HomePad \
  -destination "platform=iOS Simulator,id=$simulator" -parallel-testing-enabled NO \
  -collect-test-diagnostics never -derivedDataPath "${DERIVED_DATA_PATH:-${TMPDIR:-/tmp}/HomePadDerived}" \
  -resultBundlePath "$result_dir" CODE_SIGNING_ALLOWED=NO "$@" test
