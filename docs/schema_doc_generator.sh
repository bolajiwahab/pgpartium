#!/bin/bash

set -euo pipefail

python3 -m venv .jsfh_env

# shellcheck source=/dev/null
source .jsfh_env/bin/activate

pip3 install json-schema-for-humans==1.4.1

generate-schema-doc src/schema.json --config-file docs/schema_doc.yaml docs/docs/schema.html

deactivate
rm -rf .jsfh_env
