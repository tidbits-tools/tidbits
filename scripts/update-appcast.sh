#!/bin/bash
set -euo pipefail

# Updates appcast.xml with a new release item.
# Called by the release workflow after building and signing.
#
# Usage: ./scripts/update-appcast.sh <version> <build> <signature> <length> <dmg-url>
# Example: ./scripts/update-appcast.sh 1.1.0 2 "abc123..." 1747529 "https://github.com/.../Tidbits.dmg"

VERSION="$1"
BUILD="$2"
ED_SIGNATURE="$3"
FILE_LENGTH="$4"
DMG_URL="$5"
APPCAST="appcast.xml"
PUBLISH_DATE=$(date -u +"%a, %d %b %Y %H:%M:%S +0000")

# Insert new item after <channel><title>...</title>
# Uses sed to find the closing </title> tag and insert after it
sed "/<\/title>/a\\
    <item>\\
      <title>Version $VERSION</title>\\
      <pubDate>$PUBLISH_DATE</pubDate>\\
      <sparkle:version>$BUILD</sparkle:version>\\
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>\\
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>\\
      <enclosure\\
        url=\"$DMG_URL\"\\
        sparkle:edSignature=\"$ED_SIGNATURE\"\\
        length=\"$FILE_LENGTH\"\\
        type=\"application/octet-stream\"\\
      />\\
    </item>
" "$APPCAST" > "${APPCAST}.tmp"

mv "${APPCAST}.tmp" "$APPCAST"
echo "Updated appcast.xml with version $VERSION (build $BUILD)"
