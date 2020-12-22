"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const lodash_1 = __importDefault(require("lodash"));
const pluralize_1 = __importDefault(require("pluralize"));
const uuid_1 = require("uuid");
function enrich(type, payload) {
    if (type.split('/')[1] === 'upsert' && !(type.split('/')[0] === 'session')) {
        if (!payload.id) {
            return Object.assign(Object.assign({}, payload), { id: uuid_1.v4() });
        }
    }
    return payload;
}
function createOptDis(schema, dispatch, restClient, serverActionQueue) {
    const plurals = lodash_1.default.keys(schema).map(k => pluralize_1.default(k));
    let inFlight = false;
    function enqueueServerAction(action) {
        serverActionQueue.addItem(action);
    }
    function dispatchServerAction() {
        const action = serverActionQueue.getItem();
        if (!action)
            return;
        inFlight = true;
        restClient.post('/jason/api/action', action)
            .then(serverActionQueue.itemProcessed)
            .catch(e => {
            dispatch({ type: 'upsertLocalUi', data: { error: JSON.stringify(e) } });
            serverActionQueue.itemProcessed();
        });
    }
    setInterval(dispatchServerAction, 10);
    return function (action) {
        const { type, payload } = action;
        const data = enrich(type, payload);
        dispatch({ type, payload: data });
        if (plurals.indexOf(type.split('/')[0]) > -1) {
            enqueueServerAction({ type, payload: data });
        }
    };
}
exports.default = createOptDis;
