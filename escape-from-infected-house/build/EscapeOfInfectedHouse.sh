#!/bin/sh
printf '\033c\033]0;%s\a' Escape-from-Infected-House
base_path="$(dirname "$(realpath "$0")")"
"$base_path/EscapeOfInfectedHouse.x86_64" "$@"
