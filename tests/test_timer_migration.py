import sys,tempfile,time,unittest
from pathlib import Path
from unittest import mock
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import backend
class TimerMigrationTests(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
  p=mock.patch.object(backend,'STATE',Path(self.tmp.name)/'omarchy-notch');p.start();self.addCleanup(p.stop)
  self.old='omarchy-notch-focus-123';self.end=time.time()+45
  with backend.locked_state() as s:s.update(timer={'unit':self.old,'label':'CONFIDENTIAL','end':self.end,'duration':60},settings={'theme':'glass'})
 def test_stop_first_preserve_deadline_private_payload_and_idempotence(self):
  with mock.patch.object(backend,'run',return_value='') as run:
   backend.migrate_timer();calls=[c.args[0] for c in run.call_args_list]
   self.assertEqual(calls[1],['systemctl','--user','stop',self.old+'.timer',self.old+'.service'])
   self.assertNotIn('CONFIDENTIAL',str(calls))
   record=backend.read_json(backend.STATE/'state.json');self.assertEqual(record['timer']['end'],self.end);self.assertEqual(record['timer']['label'],'CONFIDENTIAL');self.assertTrue(record['timer']['scheduled'])
   self.assertEqual(record['settings'],{'theme':'glass'})
   run.reset_mock();backend.migrate_timer();run.assert_not_called()
 def test_failure_after_stop_persists_for_retry_without_legacy_command(self):
  def fail(argv,**kw):
   if argv[0]=='systemd-run':raise ValueError('failed')
   return ''
  with mock.patch.object(backend,'run',side_effect=fail),self.assertRaises(ValueError):backend.migrate_timer()
  pending=backend.read_json(backend.STATE/'state.json')['timer'];self.assertFalse(pending['scheduled']);self.assertNotEqual(pending['unit'],self.old);self.assertEqual(pending['end'],self.end)
  with mock.patch.object(backend,'run',return_value=''):backend.migrate_timer()
  self.assertTrue(backend.read_json(backend.STATE/'state.json')['timer']['scheduled'])
 def test_failed_stop_does_not_erase_state_or_schedule_second_timer(self):
  with mock.patch.object(backend,'stop_timer',side_effect=ValueError('stop failed')),mock.patch.object(backend,'run',return_value='loaded\nloaded') as run,self.assertRaises(ValueError):backend.migrate_timer()
  self.assertTrue(all(c.args[0][0]=='systemctl' and c.args[0][2]=='show' for c in run.call_args_list));self.assertEqual(backend.read_json(backend.STATE/'state.json')['timer']['unit'],self.old)
 def test_status_calls_migration_on_normal_refresh(self):
  with mock.patch.object(backend,'migrate_timer') as migrate,mock.patch.object(backend,'metrics',return_value={}),mock.patch.object(backend,'batteries',return_value=[]),mock.patch.object(backend,'agent_status',return_value=[]):backend.status()
  migrate.assert_called_once()

 def test_finished_legacy_timer_is_not_resurrected(self):
  with mock.patch.object(backend,'run',return_value='not-found\n\nnot-found') as run:backend.migrate_timer()
  self.assertEqual(backend.read_json(backend.STATE/'state.json')['timer'],{})
  self.assertEqual(run.call_count,1)

 def test_crash_after_stop_preserves_intent_for_retry(self):
  with mock.patch.object(backend,'run',return_value='loaded\nloaded'),mock.patch.object(backend,'stop_timer',side_effect=SystemExit),self.assertRaises(SystemExit):backend.migrate_timer()
  record=backend.read_json(backend.STATE/'state.json')['timer'];self.assertFalse(record['scheduled']);self.assertEqual(record['unit'],self.old)
  with mock.patch.object(backend,'run',return_value=''):backend.migrate_timer()
  self.assertTrue(backend.read_json(backend.STATE/'state.json')['timer']['scheduled'])
 def test_expired_legacy_is_stopped_without_duplicate_notification(self):
  with backend.locked_state() as s:s['timer']['end']=time.time()-10
  with mock.patch.object(backend,'run',return_value='loaded\nloaded') as run:backend.migrate_timer()
  self.assertEqual(backend.read_json(backend.STATE/'state.json')['timer'],{})
  self.assertFalse(any(c.args[0][0]=='systemd-run' for c in run.call_args_list))
 def test_malformed_state_does_not_break_migration(self):
  for value in [[],['bad'],{'timer':[]},{'timer':{'unit':3}}]:
   backend.atomic_json(backend.STATE/'state.json',value);backend.migrate_timer()
