"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const actionFactory_1 = __importDefault(require("./actionFactory"));
const pluralize_1 = __importDefault(require("pluralize"));
const lodash_1 = __importDefault(require("lodash"));
function createActions(schema, store, restClient, optDis, extraActions) {
    const actions = lodash_1.default.fromPairs(lodash_1.default.map(schema, (config, model) => {
        if (config.priorityScope) {
            return [pluralize_1.default(model), actionFactory_1.default(optDis, store, model, { hasPriority: true })];
        }
        else {
            return [pluralize_1.default(model), actionFactory_1.default(optDis, store, model)];
        }
    }));
    const extraActionsResolved = extraActions ? extraActions(optDis, store, restClient, actions) : {};
    return lodash_1.default.merge(actions, extraActionsResolved);
}
exports.default = createActions;
