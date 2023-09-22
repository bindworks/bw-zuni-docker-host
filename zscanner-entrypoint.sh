#!/bin/bash

set -e

## expect: ZSCANNER_JAR_URL
## expect: ZSCANNER_JAR_DIR

if ! [ -d "$ZSCANNER_JAR_DIR" ]; then
    mkdir -p "$ZSCANNER_JAR_DIR"
fi

MAX_SLEEP=60
NEXT_SLEEP=1

while NEXT_SLEEP=$(( $NEXT_SLEEP > $MAX_SLEEP ? $MAX_SLEEP : $NEXT_SLEEP )); 
        if [ $NEXT_SLEEP -gt 1 ]; then 
            echo "Waiting for $NEXT_SLEEP seconds..."; 
            (trap - INT; exec sleep $NEXT_SLEEP);
        else 
            true; 
        fi; do

    CURRENT_VERSION_EXISTS="$([ -e "$ZSCANNER_JAR_DIR/zscanner.jar" ] && echo YES || echo NO)"
    if [ "$CURRENT_VERSION_EXISTS" = "YES" ]; then
        CURRENT_VERSION_CHECKSUM="$(sha256sum "$ZSCANNER_JAR_DIR/zscanner.jar" | cut -c 1-64)"
        echo "Checking for new version..." >&2
    else
        echo "Downloading zScanner..." >&2
    fi

    if ! curl -s -o "$ZSCANNER_JAR_DIR/zscanner-new.jar" "$ZSCANNER_JAR_URL"; then
        if [ "$CURRENT_VERSION_EXISTS" = "NO" ]; then
            NEXT_SLEEP=$(( $NEXT_SLEEP * 3 ))
            echo "No current version and unable to download a fresh one. Retrying..." >&2
            continue;
        fi

        echo "Unable to download update, running local version." >&2
    else

        # a version downloaded
        NEW_VERSION_CHECKSUM="$(sha256sum "$ZSCANNER_JAR_DIR/zscanner-new.jar" | cut -c 1-64)"
        if [ "$NEW_VERSION_CHECKSUM" != "$CURRENT_VERSION_CHECKSUM" ]; then
            echo "New version downloaded, verifying..." >&2
            ls -l "$ZSCANNER_JAR_DIR/zscanner-new.jar"
            echo "Checksum: $NEW_VERSION_CHECKSUM"
            if jarsigner -verify -keystore signing-ca.keystore -storetype pkcs12 -storepass password "$ZSCANNER_JAR_DIR/zscanner-new.jar" -strict; then
                echo "New version downloaded, installing..." >&2
                mv -f "$ZSCANNER_JAR_DIR/zscanner-new.jar" "$ZSCANNER_JAR_DIR/zscanner.jar"
                echo "New version installed." >&2
            else
                echo "New version verification failed, not installing." >&2

                if [ "$CURRENT_VERSION_EXISTS" = "NO" ]; then
                    NEXT_SLEEP=$(( $NEXT_SLEEP * 3 ))
                    echo "No current version and unable to download a fresh one. Retrying..." >&2
                    continue;
                fi
            fi
        else
            echo "Downloaded version is the same as the installed one." >&2
        fi
    fi

    NEXT_SLEEP=1
    CURRENT_VERSION_CHECKSUM="$(sha256sum "$ZSCANNER_JAR_DIR/zscanner.jar" | cut -c 1-64)"

    EXITCODE=0
    java "-Dzscanner.update.enabled=true" "-Dzscanner.update.jar-url=$ZSCANNER_JAR_URL" "-Dzscanner.update.jar-sha256=$CURRENT_VERSION_CHECKSUM" $JAVA_EXTRA_ARGS -jar "$ZSCANNER_JAR_DIR/zscanner.jar" "$@" || EXITCODE=$?

    case "$EXITCODE" in
        210) continue            # update detected
           ;;
        *) exit $EXITCODE        # any other
           ;;
    esac

done
