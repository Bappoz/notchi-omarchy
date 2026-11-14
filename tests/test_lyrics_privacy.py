import io,json,sys,unittest
from pathlib import Path
from unittest import mock
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import integrations as api
class LyricsPrivacyTests(unittest.TestCase):
 def test_private_metadata_uses_stdin(self):
  metadata={'artist':'PRIVATE sender','title':'PRIVATE date','album':'PRIVATE album','duration':'42'}
  with mock.patch('sys.stdin',io.StringIO(json.dumps(metadata)+'\n')),mock.patch.object(api,'lyrics',return_value={'lyrics':[]}) as lookup:
   api.dispatch('lyrics-online',[])
  lookup.assert_called_once_with(*metadata.values())
 def test_argv_and_invalid_inputs_do_not_contact_provider(self):
  with mock.patch.object(api,'lyrics') as lookup:
   with self.assertRaises(ValueError):api.dispatch('lyrics-online',['private'])
   for text in ['[]','{"artist":42}','x'*8193]:
    with mock.patch('sys.stdin',io.StringIO(text)),self.assertRaises(ValueError):api.dispatch('lyrics-online',[])
  lookup.assert_not_called()
 def test_qml_launch_has_no_player_metadata_in_argv(self):
  text=(Path(__file__).resolve().parents[1]/'Service.qml').read_text()
  launch=text.split('argv:["python3",backendPath,"lyrics-online"',1)[1].split('callback:',1)[0]
  self.assertTrue(launch.startswith('],inputText:JSON.stringify('))
