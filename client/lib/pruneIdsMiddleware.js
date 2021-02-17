"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const lodash_1 = __importDefault(require("lodash"));
const pluralize_1 = __importDefault(require("pluralize"));
const pruneIdsMiddleware = schema => store => next => action => {
    const { type, payload } = action;
    const result = next(action);
    const state = store.getState();
    if (type === 'jasonModels/setSubscriptionIds' || type === 'jasonModels/removeSubscriptionId') {
        const { model, ids } = payload;
        let idsInSubs = [];
        lodash_1.default.map(state.jasonModels[model], (subscribedIds, k) => {
            idsInSubs = lodash_1.default.union(idsInSubs, subscribedIds);
        });
        // Find IDs currently in Redux that aren't in any subscription
        const idsToRemove = lodash_1.default.difference(state[pluralize_1.default(model)].ids, idsInSubs);
        store.dispatch({ type: `${pluralize_1.default(model)}/removeMany`, payload: idsToRemove });
    }
    return result;
};
exports.default = pruneIdsMiddleware;
