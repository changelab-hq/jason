"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const jsonpatch_1 = require("jsonpatch");
const deepCamelizeKeys_1 = __importDefault(require("./deepCamelizeKeys"));
const pluralize_1 = __importDefault(require("pluralize"));
const lodash_1 = __importDefault(require("lodash"));
const uuid_1 = require("uuid");
function diffSeconds(dt2, dt1) {
    var diff = (dt2.getTime() - dt1.getTime()) / 1000;
    return Math.abs(Math.round(diff));
}
function createPayloadHandler(dispatch, serverActionQueue, subscription, model, config) {
    console.log({ model, config });
    let payload = [];
    let previousPayload = [];
    let idx = 0;
    let patchQueue = {};
    let lastCheckAt = new Date();
    let updateDeadline = null;
    let checkInterval;
    function getPayload() {
        console.log({ getPayload: model, subscription });
        subscription.send({ getPayload: { model, config } });
    }
    function camelizeKeys(item) {
        return deepCamelizeKeys_1.default(item, key => uuid_1.validate(key));
    }
    const tGetPayload = lodash_1.default.throttle(getPayload, 10000);
    function dispatchPayload() {
        // We want to avoid updates from server overwriting changes to local state, so if there is a queue then wait.
        if (!serverActionQueue.fullySynced()) {
            console.log(serverActionQueue.getData());
            setTimeout(dispatchPayload, 100);
            return;
        }
        const includeModels = (config.includeModels || []).map(m => lodash_1.default.camelCase(m));
        console.log("Dispatching", { payload, includeModels });
        includeModels.forEach(m => {
            const subPayload = lodash_1.default.flatten(lodash_1.default.compact(camelizeKeys(payload).map(instance => instance[m])));
            const previousSubPayload = lodash_1.default.flatten(lodash_1.default.compact(camelizeKeys(previousPayload).map(instance => instance[m])));
            // Find IDs that were in the payload but are no longer
            const idsToRemove = lodash_1.default.difference(previousSubPayload.map(i => i.id), subPayload.map(i => i.id));
            dispatch({ type: `${pluralize_1.default(m)}/upsertMany`, payload: subPayload });
            dispatch({ type: `${pluralize_1.default(m)}/removeMany`, payload: idsToRemove });
        });
        const idsToRemove = lodash_1.default.difference(previousPayload.map(i => i.id), payload.map(i => i.id));
        dispatch({ type: `${pluralize_1.default(model)}/upsertMany`, payload: camelizeKeys(payload) });
        dispatch({ type: `${pluralize_1.default(model)}/removeMany`, payload: idsToRemove });
        previousPayload = payload;
    }
    function processQueue() {
        console.log({ idx, patchQueue });
        lastCheckAt = new Date();
        if (patchQueue[idx]) {
            payload = jsonpatch_1.apply_patch(payload, patchQueue[idx]);
            if (patchQueue[idx]) {
                dispatchPayload();
            }
            delete patchQueue[idx];
            idx++;
            updateDeadline = null;
            processQueue();
            // If there are updates in the queue that are ahead of the index, some have arrived out of order
            // Set a deadline for new updates before it declares the update missing and refetches.
        }
        else if (lodash_1.default.keys(patchQueue).length > 0 && !updateDeadline) {
            var t = new Date();
            t.setSeconds(t.getSeconds() + 3);
            updateDeadline = t;
            setTimeout(processQueue, 3100);
            // If more than 10 updates in queue, or deadline has passed, restart
        }
        else if (lodash_1.default.keys(patchQueue).length > 10 || (updateDeadline && diffSeconds(updateDeadline, new Date()) < 0)) {
            tGetPayload();
            updateDeadline = null;
        }
    }
    function handlePayload(data) {
        const { value, idx: newIdx, diff, latency, type } = data;
        console.log({ data });
        if (type === 'payload') {
            if (!value)
                return null;
            payload = value;
            dispatchPayload();
            idx = newIdx + 1;
            // Clear any old changes left in the queue
            patchQueue = lodash_1.default.pick(patchQueue, lodash_1.default.keys(patchQueue).filter(k => k > newIdx + 1));
            return;
        }
        patchQueue[newIdx] = diff;
        processQueue();
        if (diffSeconds((new Date()), lastCheckAt) >= 3) {
            lastCheckAt = new Date();
            console.log('Interval lost. Pulling from server');
            tGetPayload();
        }
    }
    return handlePayload;
}
exports.default = createPayloadHandler;
