"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const actionFactory_1 = require("./actionFactory");
const pluralize_1 = require("pluralize");
const lodash_1 = require("lodash");
const uuid_1 = require("uuid");
function enrich(type, payload) {
    if (type.split('/')[1] === 'upsert' && !(type.split('/')[0] === 'session')) {
        if (!payload.id) {
            return Object.assign(Object.assign({}, payload), { id: uuid_1.v4() });
        }
    }
    return payload;
}
function makeOptDis(schema, dispatch, restClient) {
    const plurals = lodash_1.default.keys(schema).map(k => pluralize_1.default(k));
    return function (action) {
        const { type, payload } = action;
        const data = enrich(type, payload);
        dispatch(action);
        if (plurals.indexOf(type.split('/')[0]) > -1) {
            return restClient.post('/jason/api/action', { type, payload: data })
                .catch(e => {
                dispatch({ type: 'upsertLocalUi', data: { error: JSON.stringify(e) } });
            });
        }
    };
}
function createActions(schema, store, restClient, extraActions) {
    const dis = store.dispatch;
    const optDis = makeOptDis(schema, dis, restClient);
    const actions = lodash_1.default.fromPairs(lodash_1.default.map(schema, (config, model) => {
        if (config.priorityScope) {
            return [pluralize_1.default(model), actionFactory_1.default(optDis, store, model, { hasPriority: true })];
        }
        else {
            return [pluralize_1.default(model), actionFactory_1.default(optDis, store, model)];
        }
    }));
    const extraActionsResolved = extraActions(optDis, store, restClient);
    return lodash_1.default.merge(actions, extraActionsResolved);
}
exports.default = createActions;
