#!/bin/bash

# Ensure we're in the right directory
cd "$(dirname "$0")"

# Start port forwarding in the background
kubectl port-forward svc/docker-test 8080:8080 -n test &
PF_PID=$!

# Wait a moment for port forwarding to establish
sleep 2

# Open the browser (works on macOS)
open http://localhost:8080

echo "Application is running at http://localhost:8080"
echo "Press Ctrl+C to stop port forwarding"

# Wait for user to press Ctrl+C
wait $PF_PID