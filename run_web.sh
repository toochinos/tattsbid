#!/bin/bash
# Run Flutter web with HTML renderer to avoid WebGL/CPU fallback warning.
exec flutter run -d chrome --web-renderer=html "$@"
