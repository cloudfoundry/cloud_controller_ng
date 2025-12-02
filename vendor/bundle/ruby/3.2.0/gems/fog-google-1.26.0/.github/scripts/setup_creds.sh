#!/bin/bash

GOOGLE_PROJECT=$(curl "http://metadata.google.internal/computeMetadata/v1/project/project-id" -H "Metadata-Flavor: Google")

# fog needs the google project to be specified even if it uses application-default creds
cat >~/.fog <<EOL
test:
  google_project: ${GOOGLE_PROJECT}
  google_application_default: true
EOL