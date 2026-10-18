#!/bin/sh
# Wraps the artifact source in a full HTML document for local preview (localhost or double-click).
cd "$(dirname "$0")"
{ printf '<!doctype html>\n<html lang="en">\n<head>\n<meta charset="utf-8">\n<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">\n</head>\n<body>\n'; cat mockup.artifact.html; printf '\n</body>\n</html>\n'; } > index.html
