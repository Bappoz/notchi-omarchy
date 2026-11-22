import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import "Plugin" as Plugin
ShellRoot {
    id:root
    Plugin.Service{id:backend;pollingEnabled:false}
    QtObject{id:fakeShell;function serviceFor(id){return backend}}
    QtObject {
        id:fakeBar
        property QtObject shell:fakeShell
        property int barSize:28
        property bool vertical:false
        property string position:"top"
        function requestPopout(item){}
        function releasePopout(item){}
        function moduleWidgets(id){return [notch]}
    }
    PanelWindow {
        id:barWindow
        anchors{top:true;left:true;right:true}
        implicitHeight:28;color:"transparent"
        Plugin.Notch{id:notch;anchors.horizontalCenter:parent.horizontalCenter;bar:fakeBar}
    }
    TestCase{id:events;when:false;name:"InputDriver"}
    function findObject(name){
        var seen=[]
        function visit(obj){
            if(!obj||seen.indexOf(obj)>=0)return null
            seen.push(obj)
            if(obj.objectName===name)return obj
            var lists=[obj.data,obj.children]
            for(var j=0;j<lists.length;j++)if(lists[j])for(var i=0;i<lists[j].length;i++){var found=visit(lists[j][i]);if(found)return found}
            if("contentItem" in obj){var f=visit(obj.contentItem);if(f)return f}
            if("item" in obj){var g=visit(obj.item);if(g)return g}
            return null
        }
        return visit(notch)
    }
    property string result:""
    property int oldTaskRevision:0
    IpcHandler {
        target:"dashboard-test"
        function prepare(style:string):void{
            notch.close()
            var pill=root.findObject("notch-pill")
            if(pill)events.mouseMove(pill,-50,pill.height/2)
            backend.snapshot={settings:{animationStyle:style},agents:[{id:"codex",name:"Codex",limits:[],note:"",stale:false,fetchedAt:0}],shelf:[]}
            backend.telemetry={metrics:{cpu:24,memory:62,memoryGB:9.9,totalGB:16},disk:{free:103079215104,total:515396075520},systemBattery:{percent:96,charging:false},network:{interface:"Wi-Fi",download:132400,upload:23400,history:[[100,20],[200,30],[120,40],[320,20],[150,60],[240,30],[100,30]]}}
            backend.tasks=[{id:"sample",title:"One clear task",note:"Notes",priority:1,done:false,day:"2099-01-01"}]
            backend.weather={temperature:22,feelsLike:21,humidity:50,wind:8,kind:"rain",fetched:1,forecast:[{time:"18:00",temperature:21,rain:80}]}
            root.result=""
        }
        function hover():string{
            var pill=root.findObject("notch-pill")
            if(!pill)return "missing-pill"
            events.mouseMove(pill,pill.width/2,pill.height/2)
            return "ok"
        }
        function enterSurface():void{var item=root.findObject("notch-live-surface");events.mouseMove(item,item.width/2,14)}
        function calendarPeekState():string {
            var clock = root.findObject("notch-clock")
            var card = root.findObject("notch-live-surface")
            var today = root.findObject("mini-calendar-today")
            return JSON.stringify({visible:notch.calendarPeek,height:card.height,dot:!!today && today.visible,
                centered:Math.abs(clock.x + clock.width / 2 - clock.parent.width / 2) < 1
                    && Math.abs(clock.y + clock.height / 2 - clock.parent.height / 2) < 1})
        }
        function island():string {
            var pill = root.findObject("notch-pill")
            var surface = root.findObject("notch-live-surface")
            return JSON.stringify({state:notch.islandState, width:pill.width, y:surface.parent.y, tab:notch.currentTab})
        }
        function timerState():string {
            backend.updateClock()
            backend.snapshot = Object.assign({},backend.snapshot,{timer:{end:backend.now+65}})
            var initial = backend.islandClock
            backend.now = Date.now()/1000 - 10
            backend.snapshot = Object.assign({},backend.snapshot,{timer:{end:backend.now+1}})
            backend.updateClock()
            var finished = backend.currentNotice.kind
            backend.snapshot = Object.assign({},backend.snapshot,{timer:{}})
            backend.clearNotices()
            backend.toggleStopwatch()
            var stopwatch = backend.islandClock
            backend.toggleStopwatch()
            return JSON.stringify({initial:initial,finished:finished,stopwatch:stopwatch})
        }
        function activeMascots():string {
            backend.telemetry = {sessions:[
                {id:"claude-1",provider:"claude",working:true},
                {id:"codex-1",provider:"codex",working:true},
                {id:"claude-2",provider:"claude",working:true}
            ]}
            var clock = root.findObject("notch-clock")
            var orbit = root.findObject("notch-orbit")
            return JSON.stringify({
                providers:backend.activeProviders,
                clockCentered:Math.abs(clock.x + clock.width / 2 - clock.parent.width / 2) < 1,
                orbit:orbit.running
            })
        }
        function orbitPhase():real { return root.findObject("notch-orbit").phase }
        function connectionStates():string {
            backend.clearNotices()
            backend.observeConnections({wifi:["existing"], headphones:["existing"]})
            var baseline = backend.currentNotice.kind || ""
            backend.observeConnections({wifi:["new"], headphones:["existing", "new"]})
            var wifi = backend.currentNotice.kind
            backend.dismissNotice()
            backend.pumpNotices()
            var headphones = backend.currentNotice.kind
            backend.clearNotices()
            backend.observeConnections({wifi:null, headphones:[]})
            backend.observeConnections({wifi:["after-gap"], headphones:[]})
            var recovered = backend.currentNotice.kind || ""
            backend.clearNotices()
            return JSON.stringify({baseline:baseline,wifi:wifi,headphones:headphones,recovered:recovered})
        }
        function media():string {
            return backend.player ? backend.player.trackTitle + ":" + backend.player.isPlaying : ""
        }
        function simulateConnection(kind:string):void {
            notch.close()
            backend.clearNotices()
            backend.enqueueNotice({kind:kind})
        }
        function simulateCall():void {
            notch.close()
            backend.clearNotices()
            backend.noticeSeen=[]
            backend.enqueueNotice({kind:"call",source:"Discord"})
        }
        function clear():void { notch.close(); backend.clearNotices() }
        function islandEvents():string {
            notch.close()
            backend.clearNotices()
            backend.noticeSeen=[]
            backend.observeAgents([{id:"1",provider:"codex",working:true}])
            var baseline=notch.islandState
            backend.observeAgents([{id:"1",provider:"codex",working:false,activity:"completed"}])
            var finished=backend.currentNotice.kind
            backend.enqueueNotice({kind:"call",source:"Discord"})
            var call=backend.currentNotice.kind
            backend.dismissNotice()
            var recent=notch.signalKind
            backend.clearNotices()
            return JSON.stringify({baseline:baseline,finished:finished,call:call,recent:recent})
        }
        function click(tab:string):string{
            var item=root.findObject("tab-"+tab)
            if(!item)return "missing-tab-"+tab
            events.mouseMove(item,item.width/2,item.height/2)
            events.mouseClick(item,item.width/2,item.height/2)
            return notch.currentTab
        }
        function leave():void{
            var surface=root.findObject("notch-live-surface")
            events.mouseMove(surface,-50,100)
        }
        function open(tab:string):void{notch.held=true;notch.openTab(tab)}
        function captureStatus():void{root.oldTaskRevision=backend.taskRevision}
        function replayStatus():void{backend.applyStatus(Object.assign({},backend.snapshot,{tasks:[],taskColor:"#e59cae"}),root.oldTaskRevision)}
        function clickObject(name:string):string{var item=root.findObject(name);if(!item)return "missing-"+name;events.mouseMove(item,item.width/2,item.height/2);events.mouseClick(item,item.width/2,item.height/2);return "ok"}
        function editTask():void{root.findObject("daily-page").expanded=backend.tasks[0].id}
        function emojiNote():int{var note=root.findObject("task-note-"+backend.tasks[0].id);note.text="z".repeat(1999)+"😀";return note.length}
        function longNote():int{var note=root.findObject("task-note-"+backend.tasks[0].id);note.text="z".repeat(2001);return note.length}
        function seedRows():string{
            backend.tasks=[{id:"a",title:"Review dashboard",note:"",priority:1,done:false,day:"2026-11-11"},{id:"hidden",title:"Yesterday",note:"",priority:1,done:true,day:"2020-01-01"},{id:"b",title:"Plan tomorrow",note:"",priority:1,done:false,day:"2026-11-11"}]
            var list=root.findObject("task-list");list.forceLayout();list.positionViewAtBeginning()
            return JSON.stringify(backend.tasks.map(function(t){return t.id}))
        }
        function dailyState():string{var list=root.findObject("task-list");return JSON.stringify({count:list.count,y:list.contentY,rows:backend.tasks.map(function(t){return t.id})})}
        function add(title:string):string{
            var input=root.findObject("task-input"), button=root.findObject("task-add")
            if(!input||!button)return "missing-task-controls"
            input.text=title;events.mouseClick(button,button.width/2,button.height/2);return "ok"
        }
        function tasks():string{return JSON.stringify({count:backend.tasks.length,busy:backend.taskBusy})}
        function detail():string{return JSON.stringify({busy:backend.detailBusy,id:backend.agentDetail.id,tokens:backend.agentDetail.todayTokens,error:backend.detailError,section:root.findObject("agents-page").section})}
        function info():string{return JSON.stringify({opened:notch.opened,held:notch.held,tab:notch.currentTab,progress:notch.progress,found:!!root.findObject("notch-live-surface"),pillHover:root.findObject("notch-pill-input").containsMouse,surfaceHover:root.findObject("notch-surface-hover").hovered})}
        function save(path:string):void{var surface=root.findObject("notch-live-surface");if(surface)surface.grabToImage(function(img){img.saveToFile(path)})}
        function releaseNotice():string{backend.expandedCount=0;notch.close();backend.pumpNotices();return backend.currentNotice.kind||""}
        function noticeState():string{return JSON.stringify({kind:backend.currentNotice.kind||"",queued:backend.noticeQueue.length})}
        function resumeNotice():string{backend.lastNoticePoll=Date.now()-30000;backend.pumpNotices();return JSON.stringify({kind:backend.currentNotice.kind||"",queued:backend.noticeQueue.length})}
        function reducedMotion():void{backend.snapshot={settings:{animationStyle:"flip3D",animations:"false"}}}
        function notices():string{
            backend.noticeQueue=[];backend.noticeSeen=[];backend.currentNotice=({});backend.lastNoticePoll=Date.now()
            // Hold a panel open while simultaneous events are queued.
            backend.expandedCount=1
            backend.enqueueNotice({kind:"agent",provider:"codex",activity:"working"})
            backend.enqueueNotice({kind:"weather",event:{id:"rain-test",kind:"rain"}})
            backend.enqueueNotice({kind:"weather",event:{id:"rain-test",kind:"rain"}})
            return JSON.stringify({queued:backend.noticeQueue.length,active:backend.currentNotice.kind||""})
        }
    }
}
