#!/bin/bash

multipleLanguages() {
    BUILDBOT="Miku UI Udon Treble Buildbot"
    BUILDBOT_EXIT="Executing in 3 seconds - CTRL-C to exit"
    SHOW_VERSION="Build version"
    INIT_MIKU_UI="Initializing Miku UI workspace"
    PREPARE_LOCAL_MANIFEST="Preparing local manifest"
    SYNC_REPOS="Syncing repos"
    APPLY_TREBLEDROID_PATCH="Applying trebledroid patches"
    APPLY_TREBLEDROID_BACKPORT_PATCH="Applying trebledroid_backport patches"
    APPLY_XIAOLEGUN_PATCH="Applying xiaoleGun patches"
    APPLY_PERSONAL_PATCH="Applying personal patches"
    SET_UP_ENVIRONMENT="Setting up build environment"
    GEN_DEVICE_MAKEFILE="Treble device generation"
    BUILD_TREBLE_APP="Building treble app"
    BUILD_TREBLE_IMAGE="Building treble image"
    # TEMP DISABLE: GEN_UP_JSON="Generating Update json"
    COMPLETED="Buildbot completed in $1 minutes and $2 seconds"
}

warning() {
    echo
    echo "-----------------------------------------"
    echo "      $BUILDBOT                          "
    echo "                  by                     "
    echo "         xiaoleGun & Ksawlii             "
    echo " $BUILDBOT_EXIT                          "
    echo "-----------------------------------------"
    echo
    echo "$SHOW_VERSION: $VERSION_CODE"
    echo 
    if [ -n "$VANILLA_ONLY" ] && [ -n "$GAPPS_ONLY" ]; then
    echo "Warning: Both VANILLA_ONLY and GAPPS_ONLY are set! This script will not build both. Please unset one."
    exit 1
    elif [ -n "$VANILLA_ONLY" ]; then
    echo "Building Vanilla only. If you want GApps build too, unset the VANILLA_ONLY variable."
    elif [ -n "$GAPPS_ONLY" ]; then
    echo "Building GApps only. If you want Vanilla build too, unset the GAPPS_ONLY variable."
    else
    echo "Building both Vanilla and GApps."
    fi
    echo
}

initRepo() {
    if [ ! -d .repo ]; then
        echo
        echo "--> $INIT_MIKU_UI"
        echo
        repo init -u https://github.com/Miku-UI/manifesto -b Udon_v2 --depth=1
    fi

    if [ -d .repo ] && [ ! -f .repo/local_manifests/miku-treble.xml ]; then
        echo
        echo "--> $PREPARE_LOCAL_MANIFEST"
        echo
        rm -rf .repo/local_manifests
        mkdir -p .repo/local_manifests
        echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<manifest>
  <remote name=\"github\"
          fetch=\"https://github.com\" />

  <project name=\"TrebleDroid/vendor_hardware_overlay\" path=\"vendor/hardware_overlay\" remote=\"github\" revision=\"pie\" />
  <project name=\"TrebleDroid/device_phh_treble\" path=\"device/phh/treble\" remote=\"github\" revision=\"android-14.0\" />
  <project name=\"TrebleDroid/vendor_interfaces\" path=\"vendor/interfaces\" remote=\"github\" revision=\"android-14.0\" />
  <project name=\"phhusson/vendor_magisk\" path=\"vendor/magisk\" remote=\"github\" revision=\"android-10.0\" />
  <project name=\"TrebleDroid/treble_app\" path=\"treble_app\" remote=\"github\" revision=\"master\" />
  <project name=\"phhusson/sas-creator\" path=\"sas-creator\" remote=\"github\" revision=\"master\" />
  <project name=\"platform/prebuilts/vndk/v28\" path=\"prebuilts/vndk/v28\" remote=\"aosp\" revision=\"204f1bad00aaf480ba33233f7b8c2ddaa03155dd\" clone-depth=\"1\" />

  <project path=\"packages/apps/QcRilAm\" name=\"AndyCGYan/android_packages_apps_QcRilAm\" remote=\"github\" revision=\"master\" />
  <project path=\"packages/apps/MikuUILyricsStubDummy\" name=\"platform_packages_apps_MikuUILyricsStubDummy\" remote="miku\" revision="master\" />
  <project path=\"packages/apps/MikuUIMusicCenter\" name=\"platform_packages_apps_MikuUIMusicCenter\" remote="miku\" revision="master\" />
</manifest>" > .repo/local_manifests/miku-treble.xml
    fi
}

syncRepo() {
    echo
    echo "--> $SYNC_REPOS"
    echo
    repo sync -c --force-sync --no-clone-bundle --no-tags -j$(nproc --all)
}

applyPatches() {
    patches="$(readlink -f -- $1)"
    tree="$2"

    for project in $(cd $patches/patches/$tree; echo *);do
        p="$(tr _ / <<<$project | sed -e 's;platform/;;g')"
        [ "$p" == treble/app ] && p=treble_app
        [ "$p" == vendor/hardware/overlay ] && p=vendor/hardware_overlay
        pushd $p
        for patch in $patches/patches/$tree/$project/*.patch; do
            git am $patch || exit
        done
        popd
    done
}

applyingPatches() {
    echo
    echo "--> $APPLY_TREBLEDROID_PATCH"
    echo
    applyPatches $SD trebledroid
    echo
    echo "--> $APPLY_TREBLEDROID_BACKPORT_PATCH"
    echo
    applyPatches $SD trebledroid_backport
    echo
    echo "--> $APPLY_XIAOLEGUN_PATCH"
    echo
    applyPatches $SD xiaoleGun
    echo
    echo "--> $APPLY_PERSONAL_PATCH"
    echo
    applyPatches $SD personal
}

initEnvironment() {
    echo
    echo "--> $SET_UP_ENVIRONMENT"
    echo
    source build/envsetup.sh &> /dev/null
    rm -rf $BD
    mkdir -p $BD
}

generateDevice() {
    echo
    echo "--> $GEN_DEVICE_MAKEFILE"
    echo
    rm -rf device/*/sepolicy/common/private/genfs_contexts
    cd device/phh/treble
    git clean -fdx
    bash generate.sh miku
    cd ../../../
}

buildTrebleApp() {
    echo
    echo "--> $BUILD_TREBLE_APP"
    echo
    cd treble_app
    bash build.sh release
    cp TrebleApp.apk ../vendor/hardware_overlay/TrebleApp/app.apk
    cd ../vendor/hardware_overlay
    git commit -a -m "Update Treble App"
    cd ../..
}

buildTreble() {
    echo
    echo "--> $BUILD_TREBLE_IMAGE: $1"
    echo
    lunch $1-ap2a-userdebug
    make -j$(nproc --all) systemimage
    mv $OUT/system.img $BD/system-$1.img
}

generatePackages() {
    echo
    echo "--> $GEN_PACKAGE: $1"
    echo
    BASE_IMAGE=$BD/system-$1.img
    mkdir --parents $BD/dsu/$1/; mv $BASE_IMAGE $BD/dsu/$1/system.img
    if [ "$NO_COMPRESS" = "true" ]; then
        mv "$BD/dsu/$1/system.img" "$BD/MikuUI-$VERSION-$VERSION_CODE-$2$3-$BUILD_DATE-UNOFFICIAL.img"
    else
        xz -cv9 --threads=0 "$BD/dsu/$1/system.img" > "$BD/MikuUI-$VERSION-$VERSION_CODE-$2$3-$BUILD_DATE-UNOFFICIAL.img.xz"
    fi
    rm -rf $BD/dsu
}

# TEMP DISABLE
#generateOtaJson() {
#    echo
#    echo "--> $GEN_UP_JSON"
#    echo
#    prefix="MikuUI-$VERSION-$VERSION_CODE-"
#    suffix="-$BUILD_DATE-UNOFFICIAL.img.gz"
#    json="{\"version\": \"$VERSION_CODE\",\"date\": \"$(date +%s -d '-4hours')\",\"variants\": ["
#    find $BD -name "*.img.xz" | {
#        while read file; do
#            packageVariant=$(echo $(basename $file) | sed -e s/^$prefix// -e s/$suffix$//)
#            case $packageVariant in
#                "arm64-ab") name="miku_treble_arm64_bvN" ;;
#                "arm64-ab-vndklite") name="miku_treble_arm64_bvN-vndklite" ;;
#                "arm64-ab-gapps") name="miku_treble_arm64_bgN" ;;
#                "arm64-ab-gapps-vndklite") name="miku_treble_arm64_bgN-vndklite" ;;
#            esac
#            size=$(wc -c $file | awk '{print $1}')
#            url="https://github.com/xiaoleGun/treble_build_miku/releases/download/$VERSION-$VERSION_CODE/$(basename $file)"
#            json="${json} {\"name\": \"$name\",\"size\": \"$size\",\"url\": \"$url\"},"
#        done
#        json="${json%?}]}"
#        echo "$json" | jq '.variants |= sort_by(.name)' > $SD/ota.json
#        cp $SD/ota.json $BD/ota.json
#    }
#}

# Performing function
START=$(date +%s)
BUILD_DATE="$(date +%Y%m%d)"

SD=$(cd $(dirname $0);pwd)
BD=$HOME/builds
VERSION=Udon_v2
VERSION_CODE=0.12.0-extended

multipleLanguages
warning

sleep 3

initRepo
syncRepo
applyingPatches
initEnvironment
generateDevice
buildTrebleApp

if [ "$VANILLA_ONLY" = "true" ]; then
    buildTreble miku_treble_arm64_bvN
elif [ "$GAPPS_ONLY" = "true" ]; then
    buildTreble miku_treble_arm64_bgN
else
    buildTreble miku_treble_arm64_bvN
    buildTreble miku_treble_arm64_bgN
fi

if [ "$VANILLA_ONLY" = "true" ]; then
    generatePackages miku_treble_arm64_bvN arm64-ab
elif [ "$GAPPS_ONLY" = "true" ]; then
    generatePackages miku_treble_arm64_bgN arm64-ab -gapps
else
    generatePackages miku_treble_arm64_bvN arm64-ab
    generatePackages miku_treble_arm64_bgN arm64-ab -gapps
fi

END=$(date +%s)
ELAPSEDM=$(($(($END - $START)) / 60))
ELAPSEDS=$(($(($END - $START)) - $ELAPSEDM * 60))

multipleLanguages $ELAPSEDM $ELAPSEDS

echo
echo "--> $COMPLETED"
echo
