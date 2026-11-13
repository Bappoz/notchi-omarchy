import sys
import json
import time
import unittest
import contextlib
import tempfile
import os
from unittest import mock
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import telemetry

class SessionMetadataTests(unittest.TestCase):
    def parse(self,rows,provider='codex',age=1):
        return telemetry.session(rows,provider,'fixture',time.time()-age,time.time())

    def test_codex_working_turn_and_usage_without_message_content(self):
        rows=[{'type':'session_meta','payload':{'cwd':'/project/demo','base_instructions':'PRIVATE PROMPT'}},
              {'type':'event_msg','payload':{'type':'task_started','turn_id':'turn','model_context_window':200000}},
              {'type':'event_msg','payload':{'type':'token_count','info':{'total_token_usage':{'total_tokens':4000},'last_token_usage':{'total_tokens':1000}}}},
              {'type':'response_item','payload':{'type':'message','content':'PRIVATE ANSWER'}}]
        row=self.parse(rows)
        self.assertTrue(row['working']);self.assertEqual(row['tokens'],4000);self.assertEqual(row['contextTokens'],1000)
        self.assertNotIn('PRIVATE',json.dumps(row))
        rows.append({'type':'event_msg','payload':{'type':'task_complete'}})
        self.assertFalse(self.parse(rows)['working'])

    def test_claude_request_and_stop_and_reported_context(self):
        rows=[{'type':'api-request','cwd':'/project/demo','params':{'secret':'PRIVATE'}},
              {'type':'assistant','message':{'model':'test','content':'PRIVATE','usage':{'input_tokens':100,'cache_read_input_tokens':200},'stop_reason':'tool_use'}}]
        row=self.parse(rows,'claude');self.assertTrue(row['working']);self.assertEqual(row['contextTokens'],300)
        self.assertIsNone(row['contextWindow']);self.assertNotIn('PRIVATE',json.dumps(row))
        rows.append({'type':'system','subtype':'turn_duration'})
        self.assertFalse(self.parse(rows,'claude')['working'])

    def test_inactive_transcript_is_not_reported_working_forever(self):
        row=self.parse([{'type':'event_msg','payload':{'type':'task_started'}}],age=301)
        self.assertFalse(row['working'])

    def test_missing_counts_remain_unknown(self):
        row=self.parse([])
        self.assertIsNone(row['tokens']);self.assertIsNone(row['contextTokens'])

    def test_codex_turn_tokens_are_not_cumulative_thread_tokens(self):
        row=self.parse([{'type':'token_usage_record','payload':{'turn_token_usage':{'total_tokens':100},'thread_token_usage':{'total_tokens':999999999}}}])
        self.assertEqual(row['tokens'],100)

class MonitoringTests(unittest.TestCase):
    def test_claude_pending_bash_is_monitoring_not_idle(self):
        rows=[{'type':'assistant','message':{'stop_reason':'tool_use','content':[{'type':'tool_use','id':'t1','name':'Bash','input':{'command':'PRIVATE COMMAND'}}]}}]
        r=telemetry.session(rows,'claude','fixture',time.time()-600,time.time())
        r=telemetry.apply_live_state(r,{'status':'busy'})
        self.assertEqual(r['activity'],'monitoring');self.assertTrue(r['working'])
        self.assertNotIn('PRIVATE',json.dumps(r))

    def test_live_shell_survives_old_transcript(self):
        r=telemetry.session([],'claude','fixture',time.time()-4000,time.time())
        r=telemetry.apply_live_state(r,{'status':'shell'})
        self.assertEqual(r['activity'],'monitoring');self.assertTrue(r['working'])

    def test_completed_tool_does_not_remain_pending(self):
        rows=[{'type':'assistant','message':{'content':[{'type':'tool_use','id':'t','name':'Bash'}]}},
              {'type':'user','message':{'content':[{'type':'tool_result','tool_use_id':'t','content':'PRIVATE RESULT'}]}},
              {'type':'api-request'}]
        r=telemetry.session(rows,'claude','fixture',time.time(),time.time())
        self.assertEqual(r['activity'],'thinking')

    def test_idle_live_agent_is_not_claimed_to_be_monitoring(self):
        r=telemetry.session([{'type':'api-request'}],'claude','fixture',time.time(),time.time())
        r=telemetry.apply_live_state(r,{'status':'idle'})
        self.assertEqual(r['activity'],'idle');self.assertFalse(r['working'])

    def test_codex_pending_command_gets_monitoring_state(self):
        rows=[{'type':'event_msg','payload':{'type':'task_started'}},
              {'type':'response_item','payload':{'type':'custom_tool_call','call_id':'a','name':'exec_command','input':'PRIVATE'}}]
        r=telemetry.session(rows,'codex','fixture',time.time(),time.time())
        self.assertEqual(r['activity'],'monitoring')

class ThinkingAndCodingTests(unittest.TestCase):
    def test_request_wait_is_thinking_and_edit_is_coding(self):
        now=time.time()
        r=telemetry.session([{'type':'api-request'}],'claude','test',now,now)
        self.assertEqual(r['activity'],'thinking')
        self.assertEqual(telemetry.apply_live_state(r,{'status':'busy'})['activity'],'thinking')
        r=telemetry.session([{'type':'assistant','message':{'content':[{'type':'tool_use','id':'edit','name':'Edit'}]}}],'claude','test',now,now)
        self.assertEqual(r['activity'],'working')

    def test_read_tool_is_reading(self):
        now=time.time()
        r=telemetry.session([{'type':'assistant','message':{'content':[{'type':'tool_use','id':'read','name':'Read'}]}}],'claude','test',now,now)
        self.assertEqual(r['activity'],'reading')

class LiveDiscoveryTests(unittest.TestCase):
    def test_live_claude_is_retained_after_thirty_minutes_of_silent_command(self):
        with tempfile.TemporaryDirectory() as directory:
            home=Path(directory);root=home/'.claude/projects/example';root.mkdir(parents=True)
            path=root/'live-session.jsonl'
            path.write_text(json.dumps({'type':'api-request','cwd':'/project/example'})+'\n')
            os.utime(path,(time.time()-4000,time.time()-4000))
            live={'live-session':{'status':'shell'}}
            with mock.patch.object(telemetry.local,'HOME',home),mock.patch.object(telemetry,'live_claude_sessions',return_value=live),mock.patch.object(telemetry,'cache_state',side_effect=lambda:contextlib.nullcontext({})),mock.patch.object(telemetry.local,'run',return_value='[]'):
                rows=telemetry.sessions()
            self.assertEqual(len(rows),1)
            self.assertEqual(rows[0]['activity'],'monitoring')
            self.assertTrue(rows[0]['working']);self.assertTrue(rows[0]['live'])
            self.assertNotIn('cwd',rows[0]);self.assertNotIn('pendingActivity',rows[0])

if __name__=='__main__':unittest.main()
