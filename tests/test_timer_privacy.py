import io,json,sys,tempfile,unittest
from pathlib import Path
from unittest import mock
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import backend
class TimerPrivacyTests(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
  p=mock.patch.object(backend,'STATE',Path(self.tmp.name)/'state');p.start();self.addCleanup(p.stop)
 def test_scheduled_command_never_contains_message(self):
  secret='CONFIDENTIAL meeting with client 14:30'
  with mock.patch.object(backend,'run',return_value='') as run:
   backend.timer_start(1,secret)
  for call in run.call_args_list:
   self.assertNotIn(secret,json.dumps(call.args))
  self.assertEqual(backend.read_json(backend.STATE/'state.json')['timer']['label'],secret)
 def test_cli_rejects_legacy_argv_message(self):
  with mock.patch.object(sys,'argv',['backend.py','timer-start','1','SECRET']),mock.patch.object(backend,'run') as run, __import__('contextlib').redirect_stdout(io.StringIO()):
   self.assertEqual(backend.main(),1)
  run.assert_not_called()
 def test_stdin_request_and_permissions(self):
  request={'minutes':1,'label':'Private synthetic reminder'}
  with mock.patch.object(sys,'argv',['backend.py','timer-start']),mock.patch.object(sys,'stdin',io.StringIO(json.dumps(request)+'\n')),mock.patch.object(backend,'run',return_value=''), __import__('contextlib').redirect_stdout(io.StringIO()):
   self.assertEqual(backend.main(),0)
  self.assertEqual((backend.STATE/'state.json').stat().st_mode & 0o777,0o600)
 def test_delivery_clear_once_cancel_and_failure(self):
  import timer_notify
  unit='omarchy-notch-focus-123'
  with mock.patch.object(timer_notify,'backend',backend):
   with backend.locked_state() as s:s['timer']={'unit':unit,'label':'Synthetic private body'};s['settings']={'theme':'glass'}
   sender=mock.Mock(side_effect=RuntimeError('Synthetic private body'))
   with self.assertRaises(RuntimeError):timer_notify.deliver(unit,sender)
   self.assertEqual(backend.read_json(backend.STATE/'state.json')['timer'],{})
   with backend.locked_state() as s:s['timer']={'unit':unit,'label':'Synthetic private body'}
   sender=mock.Mock();timer_notify.deliver(unit,sender);timer_notify.deliver(unit,sender)
   sender.assert_called_once_with('Synthetic private body')
   self.assertEqual(backend.read_json(backend.STATE/'state.json')['settings'],{'theme':'glass'})
   with backend.locked_state() as s:s['timer']={'unit':'omarchy-notch-focus-456','label':'New message'}
   timer_notify.deliver(unit,sender)
   self.assertEqual(sender.call_count,1)
   with mock.patch.object(backend,'run'):backend.timer_cancel()
   timer_notify.deliver('omarchy-notch-focus-456',sender);self.assertEqual(sender.call_count,1)
 def test_qml_sends_json_not_message_arguments(self):
  source=(Path(__file__).resolve().parents[1]/'Focus.qml').read_text()
  self.assertIn('action("timer-start", [], null, JSON.stringify(',source)

 def test_collected_units_can_be_cancelled_or_replaced(self):
  unit='omarchy-notch-focus-123'
  def run(argv,**kw):
   if argv[0]=='systemctl' and argv[2]=='stop':raise ValueError('Unit not loaded')
   if argv[0]=='systemctl' and argv[2]=='show':return 'not-found\n\nnot-found'
   return ''
  with mock.patch.object(backend,'run',side_effect=run):
   with backend.locked_state() as s:s['timer']={'unit':unit,'label':'Old'}
   backend.timer_cancel();self.assertEqual(backend.read_json(backend.STATE/'state.json')['timer'],{})
   with backend.locked_state() as s:s['timer']={'unit':unit,'label':'Old'}
   backend.timer_start(1,'New')
   self.assertNotEqual(backend.read_json(backend.STATE/'state.json')['timer']['unit'],unit)
