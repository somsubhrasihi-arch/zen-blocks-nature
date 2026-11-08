"""Apply T-BLOCK branding after Flutter generates Android scaffolding."""
from pathlib import Path
import xml.etree.ElementTree as ET
import os

ROOT = Path(__file__).resolve().parents[1]
ANDROID_NS = 'http://schemas.android.com/apk/res/android'
ET.register_namespace('android', ANDROID_NS)
res = ROOT / 'android/app/src/main/res'
manifest = ROOT / 'android/app/src/main/AndroidManifest.xml'
tree = ET.parse(manifest)
application = tree.getroot().find('application')
if application is None:
    raise SystemExit('Android application manifest was not found.')
application.set(f'{{{ANDROID_NS}}}label', 'T-BLOCK')
application.set(f'{{{ANDROID_NS}}}icon', '@mipmap/ic_launcher')
# Linking the Ads SDK requires an application ID even when ad requests are disabled.
for existing in list(application.findall('meta-data')):
    if existing.get(f'{{{ANDROID_NS}}}name') == 'com.google.android.gms.ads.APPLICATION_ID':
        application.remove(existing)
meta = ET.SubElement(application, 'meta-data')
meta.set(f'{{{ANDROID_NS}}}name', 'com.google.android.gms.ads.APPLICATION_ID')
meta.set(f'{{{ANDROID_NS}}}value', os.environ.get('ADMOB_APP_ID', 'ca-app-pub-3940256099942544~3347511713'))
if not any(n.get(f'{{{ANDROID_NS}}}name') == 'android.permission.INTERNET' for n in tree.getroot().findall('uses-permission')):
    permission = ET.SubElement(tree.getroot(), 'uses-permission')
    permission.set(f'{{{ANDROID_NS}}}name', 'android.permission.INTERNET')
tree.write(manifest, encoding='utf-8', xml_declaration=True)

tiles = [(28, 34, '#FFCF63'), (46, 34, '#FFCF63'), (64, 34, '#FFCF63'), (46, 52, '#FFCF63')]

def tile(x, y):
    return f'M{x+3},{y}h10q3,0 3,3v10q0,3 -3,3h-10q-3,0 -3,-3v-10q0,-3 3,-3z'

paths = ''.join(f'<path android:fillColor="{color}" android:strokeColor="#E9AE43" android:strokeWidth="0.7" android:pathData="{tile(x,y)}"/>' for x,y,color in tiles)
# The top bar and downward stem rotate the original home buddy by 180 degrees.
# Eyes and smile sit upright on the top-middle tile, inside the icon safe area.
paths += ''.join(f'<path android:fillColor="#FFEAAF" android:pathData="M{x+4},{y+3}h8v1.5h-8z"/>' for x,y,_ in tiles)
paths += '<path android:fillColor="#41255F" android:pathData="M50,41a1,1 0,1 0,2 0a1,1 0,1 0,-2 0M58,41a1,1 0,1 0,2 0a1,1 0,1 0,-2 0"/>'
paths += '<path android:fillColor="#00000000" android:strokeColor="#41255F" android:strokeWidth="0.8" android:strokeLineCap="round" android:pathData="M52,44Q55,48 58,44"/>'
background = '<path android:fillColor="#67419C" android:pathData="M0,0h108v108h-108z"/>'

def vector(contents):
    return f'<vector xmlns:android="{ANDROID_NS}" android:width="108dp" android:height="108dp" android:viewportWidth="108" android:viewportHeight="108">{contents}</vector>'

def write(path, content):
    destination = res / path
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(content + '\n')

# Remove the generated Flutter PNGs so density-specific resources cannot win
# over the new vector icon on older Android versions.
for path in res.glob('mipmap-*/ic_launcher.png'):
    path.unlink()
write('mipmap-anydpi/ic_launcher.xml', vector(background + paths))
write('drawable/t_block_foreground.xml', vector(paths))
write('drawable/t_block_background.xml', vector(background))
write('drawable/t_block_monochrome.xml', vector(''.join(
    f'<path android:fillColor="#FFFFFF" android:pathData="{tile(x,y)}"/>' for x,y,_ in tiles)))
adaptive = f'<adaptive-icon xmlns:android="{ANDROID_NS}"><background android:drawable="@drawable/t_block_background"/><foreground android:drawable="@drawable/t_block_foreground"/>{{monochrome}}</adaptive-icon>'
write('mipmap-anydpi-v26/ic_launcher.xml', adaptive.replace('{monochrome}', ''))
write('mipmap-anydpi-v33/ic_launcher.xml', adaptive.replace('{monochrome}', '<monochrome android:drawable="@drawable/t_block_monochrome"/>'))
print('Applied T-BLOCK label, legacy/adaptive T-piece icons and Android themed icon.')
