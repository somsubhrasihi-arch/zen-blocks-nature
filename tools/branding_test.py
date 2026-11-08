"""Check launcher resources on a generated manifest without a Flutter install."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
import xml.etree.ElementTree as ET

NS = '{http://schemas.android.com/apk/res/android}'

class BrandingTest(unittest.TestCase):
    def test_all_launcher_variants_use_the_golden_buddy(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / 'tools').mkdir()
            script = root / 'tools/configure_branding.py'
            shutil.copyfile(Path(__file__).with_name('configure_branding.py'), script)
            manifest = root / 'android/app/src/main/AndroidManifest.xml'
            manifest.parent.mkdir(parents=True)
            manifest.write_text('<manifest xmlns:android="http://schemas.android.com/apk/res/android"><application android:label="old"/></manifest>')
            res = manifest.parent / 'res'
            (res / 'mipmap-hdpi').mkdir(parents=True)
            (res / 'mipmap-hdpi/ic_launcher.png').write_bytes(b'old image')
            env = dict(os.environ, ADMOB_APP_ID='ca-app-pub-3940256099942544~3347511713')
            subprocess.run(['python', str(script)], check=True, capture_output=True, env=env)
            app = ET.parse(manifest).getroot().find('application')
            self.assertEqual(app.get(NS + 'label'), 'T-BLOCK')
            self.assertEqual(app.get(NS + 'icon'), '@mipmap/ic_launcher')
            self.assertFalse((res / 'mipmap-hdpi/ic_launcher.png').exists())
            legacy = ET.parse(res / 'mipmap-anydpi/ic_launcher.xml').getroot()
            gold = [p for p in legacy if p.get(NS + 'fillColor') == '#FFCF63']
            self.assertEqual(len(gold), 4)
            self.assertIn('M31,34', gold[0].get(NS + 'pathData'))
            self.assertIn('M49,52', gold[3].get(NS + 'pathData'))
            face_paths = [p.get(NS + 'pathData') for p in legacy
                          if p.get(NS + 'fillColor') == '#41255F'
                          or p.get(NS + 'strokeColor') == '#41255F']
            self.assertEqual(len(face_paths), 2)
            self.assertIn('M50,41', face_paths[0])
            self.assertIn('M58,41', face_paths[0])
            self.assertIn('M52,44Q55,48 58,44', face_paths[1])
            for version in ('v26', 'v33'):
                adaptive = ET.parse(res / f'mipmap-anydpi-{version}/ic_launcher.xml').getroot()
                self.assertEqual(adaptive.find('foreground').get(NS + 'drawable'), '@drawable/t_block_foreground')
            themed = ET.parse(res / 'mipmap-anydpi-v33/ic_launcher.xml').getroot()
            self.assertIsNotNone(themed.find('monochrome'))
