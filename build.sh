# Inherit variables and other things from env.sh
if [ -f treble_build_miku/env.sh ]; then
    source treble_build_miku/env.sh
else
    echo "Error: treble_build_miku/env.sh not found!" >&2
    exit 1
fi
START=$(date +%s)
BUILD_DATE="$(date +%Y%m%d)"

SD=$(cd $(dirname $0);pwd)
BD=$HOME/builds
VERSION=Udon_v2
VERSION_CODE=`grep -oP '(?<=最新版本: ).*' $SD/README.md`

multipleLanguages
warning

sleep 3

initRepo
syncRepo
applyingPatches
initEnvironment
generateDevice
buildTrebleApp

buildTreble miku_treble_arm64_bvN
buildTreble miku_treble_arm64_bgN

generatePackages miku_treble_arm64_bvN arm64-ab
generatePackages miku_treble_arm64_bgN arm64-ab -gapps

END=$(date +%s)
ELAPSEDM=$(($(($END - $START)) / 60))
ELAPSEDS=$(($(($END - $START)) - $ELAPSEDM * 60))

multipleLanguages $ELAPSEDM $ELAPSEDS

echo
echo "--> $COMPLETED"
echo
