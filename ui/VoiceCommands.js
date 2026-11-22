.pragma library

function normalize(text) {
    return String(text || "").toLowerCase().normalize("NFD")
        .replace(/[\u0300-\u036f]/g, "").replace(/[^a-z0-9]+/g, " ").trim();
}

var commands = {
    "aumentar volume": {action: "raise"},
    "aumente o volume": {action: "raise"},
    "baixar volume": {action: "lower"},
    "abaixe o volume": {action: "lower"},
    "diminuir volume": {action: "lower"},
    "diminua o volume": {action: "lower"},
    "silenciar": {action: "mute"},
    "increase volume": {action: "raise"},
    "lower volume": {action: "lower"},
    "mute": {action: "mute"},
    "pausar musica": {action: "pause"},
    "pause a musica": {action: "pause"},
    "pause music": {action: "pause"},
    "play music": {action: "play"},
    "retomar musica": {action: "play"},
    "retome a musica": {action: "play"},
    "proxima faixa": {action: "next"},
    "next track": {action: "next"}
};

var tabs = {
    calendario: "calendar", calendar: "calendar", tarefas: "daily", tasks: "daily",
    foco: "focus", focus: "focus", ajustes: "settings", settings: "settings",
    musica: "home", music: "home", clima: "weather", weather: "weather"
};

function resolve(text, applications) {
    var phrase = normalize(text);
    if (Object.prototype.hasOwnProperty.call(commands, phrase)) return commands[phrase];

    var volume = /^(?:volume|volume em|set volume to) ([0-9]{1,3})(?: (?:percent|por cento))?$/.exec(phrase);
    if (volume && Number(volume[1]) <= 100) return {action: "volume", level: Number(volume[1])};

    var open = /^(?:abra|abre|abrir|open|launch) (?:(?:o|a|the|aplicativo|app) )?(.+)$/.exec(phrase);
    if (!open) return null;
    var name = open[1];
    if (Object.prototype.hasOwnProperty.call(tabs, name)) return {action: "tab", tab: tabs[name]};

    var matches = applications.filter(function(app) {
        return [app.name, app.id.replace(/\.desktop$/, ""), app.startupClass].some(function(alias) {
            return normalize(alias) === name;
        });
    });
    return matches.length === 1 ? {action: "app", app: matches[0]} : null;
}

function windowClasses(app) {
    var id = app.id.replace(/\.desktop$/, "");
    return [app.startupClass, id, id.split(".").pop()].filter(Boolean);
}
