"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const deepCamelizeKeys_1 = __importDefault(require("./deepCamelizeKeys"));
const pluralize_1 = __importDefault(require("pluralize"));
const lodash_1 = __importDefault(require("lodash"));
const uuid_1 = require("uuid");
function diffSeconds(dt2, dt1) {
    var diff = (dt2.getTime() - dt1.getTime()) / 1000;
    return Math.abs(Math.round(diff));
}
function createPayloadHandler(dispatch, serverActionQueue, subscription, model, config, subscriptionId) {
    console.log({ model, config });
    let idx = 0;
    let patchQueue = {};
    let lastCheckAt = new Date();
    let updateDeadline = null;
    let checkInterval;
    function getPayload() {
        console.log({ getPayload: model, subscription });
        setTimeout(() => subscription.send({ getPayload: { model, config } }), 1000);
    }
    function camelizeKeys(item) {
        return deepCamelizeKeys_1.default(item, key => uuid_1.validate(key));
    }
    const tGetPayload = lodash_1.default.throttle(getPayload, 10000);
    function processQueue() {
        lastCheckAt = new Date();
        if (patchQueue[idx]) {
            if (!serverActionQueue.fullySynced()) {
                console.log(serverActionQueue.getData());
                setTimeout(processQueue, 100);
                return;
            }
            const { payload, destroy, id, type } = patchQueue[idx];
            if (type === 'payload') {
                dispatch({ type: `${pluralize_1.default(model)}/upsertMany`, payload });
                const ids = payload.map(instance => instance.id);
                dispatch({ type: `jasonModels/setSubscriptionIds`, payload: { model, subscriptionId, ids } });
            }
            else if (destroy) {
                dispatch({ type: `${pluralize_1.default(model)}/remove`, payload: id });
                dispatch({ type: `jasonModels/removeSubscriptionId`, payload: { model, subscriptionId, id } });
            }
            else {
                console.log({ payload });
                dispatch({ type: `${pluralize_1.default(model)}/upsert`, payload });
                dispatch({ type: `jasonModels/addSubscriptionId`, payload: { model, subscriptionId, id } });
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
        const { instances, idx: newIdx, diff, type } = data;
        if (type === 'payload') {
            idx = newIdx;
            // Clear any old changes left in the queue
            patchQueue = lodash_1.default.pick(patchQueue, lodash_1.default.keys(patchQueue).filter(k => k > newIdx + 1));
        }
        patchQueue[newIdx] = camelizeKeys(data);
        processQueue();
        if (diffSeconds((new Date()), lastCheckAt) >= 3) {
            lastCheckAt = new Date();
            console.log('Interval lost. Pulling from server');
            tGetPayload();
        }
    }
    tGetPayload();
    return handlePayload;
}
exports.default = createPayloadHandler;
