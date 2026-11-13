"""Bounded local telemetry. Only whitelisted session metadata leaves this module."""
import contextlib
import fcntl
import os
import tempfile
import datetime as dt
import hashlib
import json
import math
from pathlib import Path
import shutil
import time
import backend as local


@contextlib.contextmanager
def cache_state():
    # Polling samples are disposable runtime data, not durable user settings.
    root=Path(os.environ.get('XDG_RUNTIME_DIR',str(local.STATE/'runtime')))/'notchi-telemetry'
    root.mkdir(parents=True,exist_ok=True,mode=0o700)
    with (root/'lock').open('a') as lock:
        os.chmod(root/'lock',0o600)
        fcntl.flock(lock,fcntl.LOCK_EX)
        state=local.read_json(root/'cache.json',{})
        if not isinstance(state,dict):state={}
        yield state
        fd,name=tempfile.mkstemp(dir=root)
        try:
            with os.fdopen(fd,'w') as stream:json.dump(state,stream)
            os.replace(name,root/'cache.json')
        finally:
            if os.path.exists(name):os.unlink(name)


def number(value):
    try:
        value=float(value)
        return max(0,int(value)) if math.isfinite(value) else None
    except (TypeError,ValueError):return None


def records(path, limit=1_000_000):
    with path.open('rb') as stream:
        head=stream.read(32000)
        stream.seek(max(0,path.stat().st_size-limit))
        tail=stream.read(limit)
    result=[]
    for line in (head.decode(errors='replace').splitlines()+tail.decode(errors='replace').splitlines()):
        try:
            value=json.loads(line)
            if isinstance(value,dict):result.append(value)
        except ValueError:pass
    return result


def session(rows, provider, key, modified, now):
    cwd='';busy=False;tokens=None;context=None;window=None;model='';turn='';pending={};finished=False;thought=False
    for row in rows:
        payload=row.get('payload') or {}
        if not isinstance(payload,dict):continue
        if provider=='codex':
            if row.get('type')=='session_meta':cwd=str(payload.get('cwd',''));window=number(payload.get('context_window'))
            if payload.get('type')=='task_started':busy=True;finished=False;pending={};thought=True;turn=str(payload.get('turn_id',''));window=number(payload.get('model_context_window')) or window
            if payload.get('type') in ['task_complete','turn_aborted']:busy=False;finished=True;pending={}
            if row.get('type')=='response_item':
                kind=payload.get('type')
                if kind=='reasoning':thought=True
                if kind in ('function_call','custom_tool_call'):
                    pending[str(payload.get('call_id',''))]=str(payload.get('name',''));busy=True;finished=False;thought=False
                elif kind in ('function_call_output','custom_tool_call_output'):
                    pending.pop(str(payload.get('call_id','')),None)
            if row.get('type')=='turn_context':model=str(payload.get('model',''))
            if payload.get('type')=='token_count':
                info=payload.get('info') or {};total=info.get('total_token_usage') or {};last=info.get('last_token_usage') or {}
                tokens=number(total.get('total_tokens'));context=number(last.get('total_tokens'));window=number(info.get('model_context_window')) or window
            if row.get('type')=='token_usage_record':
                usage=payload.get('turn_token_usage') or {};tokens=number(usage.get('total_tokens')) or tokens
        else:
            cwd=str(row.get('cwd') or cwd)
            if row.get('type') in ['user','api-request']:busy=True;finished=False;thought=True
            message=row.get('message') or {}
            if isinstance(message,dict) and isinstance(message.get('content'),list):
                for block in message['content']:
                    if not isinstance(block,dict):continue
                    if block.get('type')=='tool_use':pending[str(block.get('id',''))]=str(block.get('name',''));busy=True;finished=False;thought=False
                    if block.get('type')=='tool_result':pending.pop(str(block.get('tool_use_id','')),None)
            if isinstance(message,dict) and row.get('type')=='assistant':
                usage=message.get('usage') or {};model=str(message.get('model') or model)
                values=[number(usage.get(k)) for k in ['input_tokens','cache_read_input_tokens','cache_creation_input_tokens']]
                if any(v is not None for v in values):context=sum(v or 0 for v in values)
                if message.get('stop_reason') in ['end_turn','stop_sequence']:busy=False;finished=True;pending={}
            if row.get('type')=='system' and row.get('subtype')=='turn_duration':busy=False;finished=True;pending={}
            if row.get('type')=='cost-state':
                amounts=row.get('modelUsage') or {}
                tokens=sum((number(v.get('inputTokens')) or 0)+(number(v.get('outputTokens')) or 0) for v in amounts.values() if isinstance(v,dict)) or tokens
    pending_activity=''
    names=[name.lower() for name in pending.values()]
    if any(name in ('bash','exec_command','shell_command','write_stdin','taskoutput','wait') for name in names):pending_activity='monitoring'
    elif any(name in ('read','grep','glob','webfetch','websearch') for name in names):pending_activity='reading'
    activity=(pending_activity or ('thinking' if thought else 'working')) if busy else ('completed' if finished and now-modified<20 else 'idle')
    if busy and now-modified>=300:activity='unknown'
    # Silence is not proof that an agent is still working indefinitely.
    busy=busy and 0<=now-modified<300
    return {'id':key,'provider':provider,'project':local.clean(Path(cwd).name or provider,70),
            'cwd':cwd,'working':busy,'activity':activity,'pendingActivity':pending_activity,'tokens':tokens,'contextTokens':context,'contextWindow':window,
            'model':local.clean(model,80),'age':round(max(0,now-modified)),'turn':local.clean(turn,100)}


def live_claude_sessions():
    result={}
    for path in (local.HOME/'.claude/sessions').glob('*.json'):
        raw=local.read_json(path,{},limit=32000)
        if not isinstance(raw,dict):continue
        try:
            pid=int(raw['pid']);fields=(Path('/proc')/str(pid)/'stat').read_text().rsplit(')',1)[1].split()
            if str(raw.get('procStart',''))!=fields[19]:continue
            identity=str(raw.get('sessionId',''))
            if identity:result[identity]={'status':str(raw.get('status','')),'cwd':str(raw.get('cwd','')),'pid':pid}
        except (OSError,KeyError,ValueError,IndexError,TypeError):continue
    return result


def apply_live_state(row, live):
    row=dict(row)
    status=live.get('status')
    if status in ('busy','shell'):
        row['activity']='monitoring' if status=='shell' else row.get('pendingActivity') or ('thinking' if row.get('activity')=='thinking' else 'working')
        row['working']=True
    elif status=='idle':
        row['activity']='completed' if row.get('activity')=='completed' and row['age']<20 else 'idle'
        row['working']=False
    elif status in ('waiting','permission'):
        row['activity']='waiting';row['working']=False
    return row


def sessions():
    now=time.time();result=[];live=live_claude_sessions()
    roots=[('claude',local.HOME/'.claude/projects'),('codex',local.HOME/'.codex/sessions')]
    with cache_state() as state:
        cache=state.setdefault('sessionMetadata',{})
        for provider,root in roots:
            files=[]
            for path in root.rglob('*.jsonl'):
                try:
                    stamp=path.stat().st_mtime
                    if now-stamp<1800 or (provider=='claude' and path.stem in live):files.append((stamp,path))
                except OSError:pass
            for stamp,path in sorted(files,reverse=True)[:24]:
                key=hashlib.sha256(str(path).encode()).hexdigest()[:18]
                try:
                    old=cache.get(key,{})
                    if old.get('modified')!=stamp or old.get('version')!=4:
                        row=session(records(path),provider,key,stamp,now)
                        cache[key]={'version':4,'modified':stamp,'row':row}
                    else:row=dict(old['row'])
                    row['age']=round(max(0,now-stamp))
                    if row['age']>=300:
                        row['working']=False
                        if row.get('activity') not in ('idle','waiting'):row['activity']='unknown'
                    if row.get('activity')=='completed' and row['age']>=20:row['activity']='idle'
                    row['live']=provider=='claude' and path.stem in live
                    if row['live']:row=apply_live_state(row,live[path.stem])
                    result.append(dict(row))
                except (OSError,ValueError,TypeError,KeyError):continue
        keep={r['id'] for r in result};state['sessionMetadata']={k:v for k,v in cache.items() if k in keep}
    # Resolve a workspace only from a matching process cwd or an unambiguous app window.
    try:clients=json.loads(local.run(['hyprctl','-j','clients']))
    except (ValueError,OSError):clients=[]
    processes={}
    for process in Path('/proc').glob('[0-9]*'):
        try:
            pid=int(process.name);fields=(process/'stat').read_text().rsplit(')',1)[1].split()
            processes[pid]=(int(fields[1]),str((process/'cwd').resolve()))
        except (OSError,ValueError,IndexError):pass
    for row in result:
        matches=[]
        for client in clients:
            app=str(client.get('class','')).lower()
            matched=row['provider']=='codex' and ('codex' in app or 'chatgpt' in app)
            for pid,(_,cwd) in processes.items():
                if cwd!=row['cwd']:continue
                seen=set()
                while pid in processes and pid not in seen:
                    if pid==client.get('pid'):matched=True;break
                    seen.add(pid);pid=processes[pid][0]
            if matched:matches.append(client.get('workspace',{}).get('id'))
        matches=list(set(x for x in matches if x is not None))
        row['workspace']=matches[0] if len(matches)==1 else None
        row.pop('cwd',None);row.pop('turn',None);row.pop('pendingActivity',None)
    return sorted(result,key=lambda r:(not r['working'],not r.get('live'),r['age']))[:24]


def network():
    names=[]
    try:
        for line in Path('/proc/net/route').read_text().splitlines()[1:]:
            fields=line.split()
            if fields[1]=='00000000':names.append(fields[0])
        if not names:return {'interface':'','download':0,'upload':0,'history':[]}
        name=names[0];base=Path('/sys/class/net')/name/'statistics'
        rx=int((base/'rx_bytes').read_text());tx=int((base/'tx_bytes').read_text());now=time.monotonic()
        with cache_state() as state:
            old=state.get('networkSample',{});elapsed=now-old.get('time',now)
            valid=old.get('name')==name and 0<elapsed<120
            down=max(0,(rx-old.get('rx',rx))/elapsed) if valid else 0
            up=max(0,(tx-old.get('tx',tx))/elapsed) if valid else 0
            history=(old.get('history',[])+[[round(down),round(up)]])[-32:] if valid else [[0,0]]
            state['networkSample']={'name':name,'rx':rx,'tx':tx,'time':now,'history':history}
        return {'interface':name,'download':round(down),'upload':round(up),'history':history}
    except (OSError,ValueError,IndexError):return {'interface':'','download':0,'upload':0,'history':[]}


def snapshot():
    disk=shutil.disk_usage(local.HOME);power=local.batteries()
    return {'metrics':local.metrics(),'disk':{'used':disk.used,'free':disk.free,'total':disk.total},
            'network':network(),'systemBattery':local.system_battery(power),'sessions':sessions()}
