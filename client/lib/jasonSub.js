"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
var jsonpatch_1 = require("jsonpatch");
var humps_1 = require("humps");
function diffSeconds(dt2, dt1) {
    var diff = (dt2.getTime() - dt1.getTime()) / 1000;
    return Math.abs(Math.round(diff));
}
function default_1(config, callbacks) {
    var models = _.keys(config);
    var payloads = _.fromPairs(models.map(function (m) { return [m, []]; })); // []
    var idxs = _.fromPairs(models.map(function (m) { return [m, 0]; }));
    var patchQueues = _.fromPairs(models.map(function (m) { return [m, {}]; }));
    console.log({ models: models, config: config, patchQueues: patchQueues });
    var lastCheckAt = new Date();
    var updateDeadline = null;
    var checkInterval;
    var subscription;
    function getPayload() {
        console.log('GETTING PAYLOAD');
        subscription.send({ type: 'get_payload' });
    }
    var tGetPayload = _.throttle(getPayload, 10000);
    function processQueue(model) {
        lastCheckAt = new Date();
        if (patchQueues[model][idxs[model]]) {
            payloads[model] = jsonpatch_1.default.apply_patch(payloads[model], patchQueues[model][idxs[model]]);
            if (patchQueues[model][idxs[model]].length > 0) {
                callbacks[model](_.fromPairs(humps_1.camelizeKeys(payloads[model]).map(function (e) { return [e.id, e]; })));
            }
            delete patchQueues[model][idxs[model]];
            idxs[model]++;
            updateDeadline = null;
            processQueue(model);
            // If there are updates in the queue that are ahead of the index, some have arrived out of order
            // Set a deadline for new updates before it arrives.
        }
        else if (_.keys(patchQueues[model]).length > 0 && !updateDeadline) {
            var t = new Date();
            t.setSeconds(t.getSeconds() + 3);
            updateDeadline = t;
            setTimeout(processQueue, 3100);
            // If more than 10 updates in queue, or deadline has passed, restart
        }
        else if (_.keys(patchQueues[model]).length > 10 || (updateDeadline && diffSeconds(updateDeadline, new Date()) < 0)) {
            tGetPayload();
            updateDeadline = null;
        }
    }
    var consumer = window.cable.consumer;
    subscription = consumer.subscriptions.create({
        channel: 'Jason::Channel',
        config: config
    }, {
        connected: function () { console.log('started here'); tGetPayload(); },
        received: (function (data) {
            console.log({ data: data });
            var type = data.type, models = data.models;
            _.map(models, function (data, u_model) {
                var model = _.camelCase(u_model);
                var value = data.value, newIdx = data.idx, diff = data.diff, latency = data.latency;
                console.log({ data: data });
                if (type === 'payload') {
                    if (!value)
                        return null;
                    payloads[model] = value;
                    callbacks[model](_.fromPairs(humps_1.camelizeKeys(value).map(function (e) { return [e.id, e]; })));
                    idxs[model] = newIdx + 1;
                    // Clear any old changes left in the queue
                    patchQueues[model] = _.pick(patchQueues[model], _.keys(patchQueues[model]).filter(function (k) { return k > newIdx + 1; }));
                    return;
                }
                patchQueues[model][newIdx] = diff;
                console.log('received', config, { idx: idxs[model], newIdx: newIdx, latency: latency, diff: diff, patchQueue: patchQueues[model] });
                processQueue(model);
                if (diffSeconds((new Date()), lastCheckAt) >= 3) {
                    lastCheckAt = new Date();
                    console.log('Interval lost. Pulling from server');
                    subscription.send({ type: 'get_payload' });
                }
            });
        })
    });
    // Return so that it can be used in a useEffect to cancel subsciption
    return function () { return consumer.subscriptions.remove(subscription); };
}
exports.default = default_1;
