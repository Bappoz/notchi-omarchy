.pragma library

var dock = [
    {id: "quick", icon: "emblem-overview", key: "island.open", color: "#ced7ec"},
    {id: "home", icon: "emblem-music", key: "media", color: "#ff8ba6"},
    {id: "agents", icon: "emblem-agents", key: "nav.agents", color: "#c7adff"},
    {id: "camera", icon: "emblem-camera", key: "nav.camera", color: "#81eb9f"},
    {id: "voice", icon: "emblem-voice", key: "voice.title", action: "voice"},
    {id: "files", icon: "emblem-files", key: "nav.files", color: "#9dc9ff"},
    {id: "clipboard", icon: "emblem-clipboard", key: "nav.clipboard", color: "#a4d5ff"},
    {id: "focus", icon: "emblem-focus", key: "focus", color: "#ffc17c"},
    {id: "daily", icon: "emblem-tasks", key: "nav.daily", color: "#86e4c2"},
    {id: "weather", icon: "emblem-weather", key: "nav.weather", color: "#8edcff"},
    {id: "system", icon: "emblem-system", key: "nav.system", color: "#a7baff"},
    {id: "calendar", icon: "emblem-calendar", key: "calendar", color: "#ff9b94"}
];

var settings = {id: "settings", icon: "settings", key: "settings", color: "#b3c2e6"};
var tools = {id: "tools", icon: "terminal", key: "tools", color: "#c7bbc9"};

function page(id) {
    return dock.find(function(item) { return item.id === id; }) || (id === "tools" ? tools : settings);
}
