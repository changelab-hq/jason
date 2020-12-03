"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const pluralize_1 = require("pluralize");
const lodash_1 = require("lodash");
const uuid_1 = require("uuid");
exports.default = (dis, store, entity, { extraActions = {}, hasPriority = false } = {}) => {
    function add(data = {}) {
        const id = uuid_1.v4();
        return dis({ type: `${pluralize_1.default(entity)}/add`, payload: Object.assign({ id }, data) });
    }
    function upsert(id, data) {
        return dis({ type: `${pluralize_1.default(entity)}/upsert`, payload: Object.assign({ id }, data) });
    }
    function movePriority(id, priority, parentFilter = {}) {
        return dis({ type: `${pluralize_1.default(entity)}/movePriority`, payload: { id, priority, parentFilter } });
    }
    function setAll(data) {
        return dis({ type: `${pluralize_1.default(entity)}/setAll`, payload: data });
    }
    function remove(id) {
        return dis({ type: `${pluralize_1.default(entity)}/remove`, payload: id });
    }
    const extraActionsResolved = lodash_1.default.mapValues(extraActions, v => v(dis, store, entity));
    if (hasPriority) {
        return Object.assign({ add, upsert, setAll, remove, movePriority }, extraActionsResolved);
    }
    else {
        return Object.assign({ add, upsert, setAll, remove }, extraActionsResolved);
    }
};
