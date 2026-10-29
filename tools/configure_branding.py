"""Apply T-BLOCK branding after Flutter generates Android scaffolding."""
from pathlib import Path
import xml.etree.ElementTree as ET

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
tree.write(manifest, encoding='utf-8', xml_declaration=True)

tiles = [(28, 34, '#56E5FA'), (46, 34, '#63D7FA'), (64, 34, '#82B8FF'), (46, 52, '#8B8CF8')]

def tile(x, y):
    return f'M{x+3},{y}h10q3,0 3,3v10q0,3 -3,3h-10q-3,0 -3,-3v-10q0,-3 3,-3z'

paths = ''.join(f'<path android:fillColor="{color}" android:strokeColor="#E9FBFF" android:strokeWidth="0.7" android:pathData="{tile(x,y)}"/>' for x,y,color in tiles)
background = '<path android:fillColor="#090B31" android:pathData="M0,0h108v108h-108z"/>'

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
