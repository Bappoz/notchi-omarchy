.pragma library

var priority = {
    call: 4, attention: 3, timer: 3, transfer: 2, done: 2,
    report: 2, wifi: 2, headphones: 2, bluetooth: 2,
    charging: 2, lowBattery: 3, chargeFull: 2, agent: 1, chat: 1, notification: 1, weather: 0
};

function queue(pending, event) {
    return pending.filter(function(item) { return item.group !== event.group; })
        .concat([event])
        .sort(function(a, b) { return priority[b.kind] - priority[a.kind] || a.queuedAt - b.queuedAt; })
        .slice(0, 4);
}

function agentEvents(previous, sessions) {
    var events = [];
    for (var session of sessions) {
        var before = previous[session.id];
        var kind = session.working && before !== "active" ? "agent"
            : before === "active" && session.activity === "completed" ? "done"
            : before === "active" && session.activity === "waiting" ? "attention" : "";
        if (kind) events.push({kind: kind, provider: session.provider, tab: "agents/activity"});
    }
    return events;
}

function agentStates(sessions) {
    var states = Object.create(null);
    for (var session of sessions)
        states[session.id] = session.working ? "active" : session.activity;
    return states;
}


function newConnections(previous, sample) {
    var events = [];
    for (var kind of ["wifi", "headphones"]) {
        if (Array.isArray(previous[kind]) && Array.isArray(sample[kind])
                && sample[kind].some(function(id) { return !previous[kind].includes(id); }))
            events.push({kind: kind});
    }
    if (previous.devices && sample.devices) {
        for (var id of Object.keys(sample.devices)) {
            if (Object.prototype.hasOwnProperty.call(previous.devices, id)) continue;
            var device = sample.devices[id];
            events.push({kind: device.audio ? "headphones" : "bluetooth", deviceId: id, device: device});
        }
    }
    return events;
}

function powerEvent(previous, sample) {
    if (!previous || !sample) return "";
    if (!sample.plugged && sample.level <= 20
            && (previous.level > 20 || previous.plugged)) return "lowBattery";
    if (sample.plugged && !previous.plugged) return "charging";
    if (sample.plugged && (sample.full || sample.level === 100)
            && previous.charging && !previous.full && previous.level < 100) return "chargeFull";
    if (sample.plugged && sample.charging && !previous.charging && !previous.full) return "charging";
    return "";
}
