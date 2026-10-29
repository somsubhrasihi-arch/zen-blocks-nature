"""Make the generated Android release configuration explicit and repeatable."""
import argparse
import base64
import os
from pathlib import Path
import re

parser = argparse.ArgumentParser()
parser.add_argument('--signed', choices=['true', 'false'], default='false')
args = parser.parse_args()
signed = args.signed == 'true'
gradle = Path('android/app/build.gradle.kts')
source = gradle.read_text()
debug_signing = 'signingConfig = signingConfigs.getByName("debug")'
if source.count(debug_signing) != 1:
    raise SystemExit('Unexpected Android template: refusing to guess the release signing configuration.')
source = re.sub(r'compileSdk\s*=\s*flutter\.compileSdkVersion', 'compileSdk = 36', source)
source = re.sub(r'targetSdk\s*=\s*flutter\.targetSdkVersion', 'targetSdk = 36', source)
if 'targetSdk = 36' not in source:
    raise SystemExit('Target API configuration was not found.')
expected_id = 'applicationId = "com.zenblocks.nature.zen_blocks"'
if expected_id not in source:
    raise SystemExit('Unexpected application ID: preserve the existing identity before building.')
if signed:
    required = ['ZEN_UPLOAD_KEYSTORE_BASE64', 'ZEN_UPLOAD_STORE_PASSWORD',
                'ZEN_UPLOAD_KEY_ALIAS', 'ZEN_UPLOAD_KEY_PASSWORD', 'ZEN_UPLOAD_KEYSTORE_PATH']
    missing = [key for key in required if not os.environ.get(key)]
    if missing:
        raise SystemExit('Signed build requires repository secrets: ' + ', '.join(missing))
    keystore = Path(os.environ['ZEN_UPLOAD_KEYSTORE_PATH'])
    keystore.write_bytes(base64.b64decode(os.environ['ZEN_UPLOAD_KEYSTORE_BASE64'], validate=True))
    keystore.chmod(0o600)
    config = '''    signingConfigs {
        create("upload") {
            storeFile = file(System.getenv("ZEN_UPLOAD_KEYSTORE_PATH"))
            storePassword = System.getenv("ZEN_UPLOAD_STORE_PASSWORD")
            keyAlias = System.getenv("ZEN_UPLOAD_KEY_ALIAS")
            keyPassword = System.getenv("ZEN_UPLOAD_KEY_PASSWORD")
        }
    }

'''
    if source.count('    buildTypes {') != 1:
        raise SystemExit('Unexpected Android buildTypes configuration.')
    source = source.replace('    buildTypes {', config + '    buildTypes {', 1)
    source = source.replace(debug_signing, 'signingConfig = signingConfigs.getByName("upload")')
else:
    source = source.replace(debug_signing, '// Unsigned preview; never upload this bundle to Play Console.')
gradle.write_text(source)
print('Configured signed upload bundle.' if signed else 'Configured unsigned release preview; not for Play Console upload.')
