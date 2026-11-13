"""Opt-in compositor tests with a synthetic image, without camera or network access."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(os.environ.get('NOTCHI_UI_TESTS') == '1', 'Set NOTCHI_UI_TESTS=1 in a Wayland session')
class RenderRegressionTests(unittest.TestCase):
    def test_waveform_moves_and_camera_styles_change_pixels(self):
        from PIL import Image, ImageChops, ImageStat
        with tempfile.TemporaryDirectory(prefix='notchi-ui-') as directory:
            folder = Path(directory)
            shutil.copy2(ROOT/'tests/ui/shell.qml', folder/'shell.qml')
            (folder/'Plugin').symlink_to(ROOT, target_is_directory=True)
            for name in ['Commons', 'Ui']:
                (folder/name).symlink_to(Path('/usr/share/omarchy/shell')/name, target_is_directory=True)
            fixture = Image.new('RGB', (160, 120))
            fixture.putdata([(220-x, 60+y, 45+x+y//2) for y in range(120) for x in range(160)])
            fixture.save(folder/'fixture.png')
            command = ['quickshell', '--path', str(folder/'shell.qml')]
            def ipc(*args):
                return subprocess.run(['quickshell','ipc','--path',str(folder/'shell.qml'),'call','ui-regression',*args], capture_output=True,text=True,timeout=5)
            with (folder/'log.txt').open('w') as log:
                process = subprocess.Popen(command+['--no-color'],stdout=log,stderr=log)
                try:
                    deadline=time.monotonic()+6
                    while True:
                        result=ipc('bars')
                        if result.returncode==0 and result.stdout.strip():break
                        if process.poll() is not None or time.monotonic()>deadline:
                            self.fail((folder/'log.txt').read_text())
                        time.sleep(.08)
                    pets=json.loads(ipc('pets').stdout)
                    self.assertEqual('gpt',pets['gpt'])
                    self.assertEqual('claude',pets['claude'])
                    deadline=time.monotonic()+4
                    while json.loads(ipc('pets').stdout)['frames']==pets['frames']:
                        self.assertLess(time.monotonic(),deadline,'Mascot rig did not animate')
                        time.sleep(.1)
                    first=json.loads(result.stdout)
                    time.sleep(.3)
                    second=json.loads(ipc('bars').stdout)
                    self.assertTrue(any(abs(a-b)>1 for a,b in zip(first,second)),(first,second))
                    names=['natural','mono','noir','silver','sepia','warm','cool','pastel','vivid','cinema','fade','rose','amber','mint','blue','lavender','glow','crisp']
                    for name in names:
                        self.assertEqual(ipc('capture',name).returncode,0)
                        deadline=time.monotonic()+3
                        while not (folder/(name+'.png')).exists():
                            self.assertLess(time.monotonic(),deadline,name)
                            time.sleep(.025)
                    natural=Image.open(folder/'natural.png').convert('RGB')
                    for name in names[1:]:
                        image=Image.open(folder/(name+'.png')).convert('RGB')
                        self.assertGreater(sum(ImageStat.Stat(ImageChops.difference(natural,image)).mean)/3,.25,name)
                    red,green,_=Image.open(folder/'mono.png').convert('RGB').split()
                    self.assertLess(max(ImageStat.Stat(ImageChops.difference(red,green)).mean),1.5)
                finally:
                    subprocess.run(['quickshell','kill','--path',str(folder/'shell.qml')],capture_output=True,timeout=5)
                    try:process.wait(timeout=3)
                    except subprocess.TimeoutExpired:process.kill();process.wait()
                    log.flush()
                    diagnostic=(folder/'log.txt').read_text()
                    self.assertNotIn('ReferenceError',diagnostic)
                    self.assertNotIn('TypeError',diagnostic)


if __name__ == '__main__':
    unittest.main()
