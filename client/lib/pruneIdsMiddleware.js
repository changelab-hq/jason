"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const lodash_1 = __importDefault(require("lodash"));
const pluralize_1 = __importDefault(require("pluralize"));
const pruneIdsMiddleware = schema => store => next => action => {
    const { type } = action;
    const result = next(action);
    const state = store.getState();
    if (type === 'jasonModels/setSubscriptionIds') {
        // Check every model
        lodash_1.default.map(lodash_1.default.keys(schema), model => {
            let ids = [];
            lodash_1.default.map(state.jasonModels[model], (subscribedIds, k) => {
                ids = lodash_1.default.union(ids, subscribedIds);
            });
            // Find IDs currently in Redux that aren't in any subscription
            const idsToRemove = lodash_1.default.difference(state[pluralize_1.default(model)].ids, ids);
            store.dispatch({ type: `${pluralize_1.default(model)}/removeMany`, payload: idsToRemove });
        });
    }
    return result;
};
exports.default = pruneIdsMiddleware;
