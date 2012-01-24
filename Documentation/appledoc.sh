#!/bin/bash
#
# Generate an Xcode docset using appledoc
#
# I use Xcode-compatible variable names where possible to facilitate
# running the script from an Xcode run script phase as well as a command line.
#
#set -x
#
set -e

: ${APPLEDOC:=/usr/local/bin/appledoc}
: ${APPLEDOC_OUTPUT:=./Documentation}
: ${PROJECT_DIR:=../}
: ${PROJECT_NAME:="SOExtendedAttributes"}
: ${BUILD_VERSION:="1.0"}

if [ -z ${APPLEDOC} ] || ! [ -x ${APPLEDOC} ]; then
echo "error: can't find the appledoc binary at $APPLEDOC"
exit -1
fi

# Set working directory to the project root
#
cd ${PROJECT_DIR}
echo "working directory: $PWD"

# Run the system's appledoc tool, specifying paths relative to the project root
#
printf "Using appledoc from %s\n" ${APPLEDOC}

${APPLEDOC} \
--project-name="SOExtendedAttributes" \
--project-version=${BUILD_VERSION} \
--project-company="Standard Orbit" \
--company-id="net.standardorbit" \
--logformat="xcode" \
--no-repeat-first-par \
--no-warn-invalid-crossref \
--ignore="Documentation" \
--ignore="UnitTests" \
--ignore="SOLoggerDemo" \
--keep-intermediate-files \
--create-docset \
--install-docset \
--docset-install-path="Documentation" \
--docset-bundle-name="SOExtendedAttributes" \
--docset-desc="SOExtendedAttributes defines cateogry on NSURL for manipulating extended attributes on a file system object." \
--print-settings \
--verbose=4 \
--output=${TMPDIR}appledoc-${PROJECT_NAME} \
--clean-output \
$PWD

