import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import photos

@unittest.skipUnless(shutil.which('magick'),'ImageMagick is required for photo export tests')
class PhotoExportTests(unittest.TestCase):
    def setUp(self):
        self.directory=tempfile.TemporaryDirectory();self.addCleanup(self.directory.cleanup)
        self.base=Path(self.directory.name);self.source=self.base/'original.png'
        subprocess.run(['magick','-size','64x48','gradient:#415b9a-#ffe9ca',str(self.source)],check=True)
        self.original=self.source.read_bytes()
        for key,value in {'STATE':self.base/'state','DATA':self.base/'data'}.items():
            patch=mock.patch.object(photos.local,key,value);patch.start();self.addCleanup(patch.stop)

    def test_every_look_exports_a_separate_photo_and_preserves_original(self):
        outputs=[]
        for name in photos.LOOKS:
            with self.subTest(look=name):
                result=photos.photo_style(str(self.source),name)
                path=Path(result['path']);self.assertTrue(path.is_file());self.assertGreater(path.stat().st_size,0)
                self.assertNotEqual(path,self.source);outputs.append(path)
        self.assertEqual(len(set(outputs)),18)
        self.assertEqual(self.source.read_bytes(),self.original)

    def test_drawing_and_each_frame_export_without_overwriting_source(self):
        for frame in ['polaroid','stars','tape']:
            with self.subTest(frame=frame):
                result=photos.photo_style(str(self.source),'natural',frame,json.dumps([[[.1,.2],[.9,.8]]]))
                self.assertTrue(Path(result['path']).is_file())
        self.assertEqual(self.source.read_bytes(),self.original)

    def test_invalid_drawing_or_look_does_not_export(self):
        for look,points in [('unexpected','[]'),('natural','[[[2,0],[1,1]]]'),('natural','[[["shell",0],[1,1]]]')]:
            with self.subTest(look=look,points=points):
                with self.assertRaises((TypeError,ValueError)):
                    photos.photo_style(str(self.source),look,'none',points)
        self.assertFalse((self.base/'data/photos').exists())
        self.assertEqual(self.source.read_bytes(),self.original)

if __name__=='__main__':unittest.main()
