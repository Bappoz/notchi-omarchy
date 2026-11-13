import QtQuick
import Quickshell
import Quickshell.Io
import "Plugin/ui" as UI
ShellRoot {
    PanelWindow {
        anchors {top:true;right:true}
        margins {top:60;right:20}
        implicitWidth:320;implicitHeight:148;color:"black"
        Item {
            id:surface;width:160;height:120
            Image {anchors.fill:parent;source:"fixture.png";layer.enabled:true;layer.effect:UI.CameraEffect{look:settings.look}}
        }
        UI.AgentPet{id:gpt;x:160;width:80;height:100;provider:"codex";activity:"monitoring"}
        UI.AgentPet{id:clawd;x:240;width:80;height:100;provider:"claude";activity:"working"}
        UI.Waveform {id:wave;x:65;y:124;playing:true;width:26;height:20}
    }
    QtObject {id:settings;property string look:"natural"}
    Timer {
        id:save;interval:140
        onTriggered:surface.grabToImage(function(result){result.saveToFile(Qt.resolvedUrl(settings.look+".png").toString().replace(/^file:\/\//,""))})
    }
    IpcHandler {
        target:"ui-regression"
        function pets():string{return JSON.stringify({gpt:gpt.character,claude:clawd.character,frames:[gpt.phase,clawd.phase]})}
        function capture(look:string):void{settings.look=look;save.restart()}
        function bars():string{
            return JSON.stringify(wave.children[0].children.filter(function(c){return "index" in c}).map(function(c){return c.children[0].height}))
        }
    }
}
