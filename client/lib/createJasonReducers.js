"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const toolkit_1 = require("@reduxjs/toolkit");
const pluralize_1 = __importDefault(require("pluralize"));
const lodash_1 = __importDefault(require("lodash"));
function generateSlices(schema) {
    const sliceNames = schema.map(k => pluralize_1.default(k));
    const adapter = toolkit_1.createEntityAdapter();
    return lodash_1.default.fromPairs(lodash_1.default.map(sliceNames, name => {
        return [name, toolkit_1.createSlice({
                name,
                initialState: adapter.getInitialState(),
                reducers: {
                    upsert: adapter.upsertOne,
                    upsertMany: adapter.upsertMany,
                    add: adapter.addOne,
                    setAll: adapter.setAll,
                    remove: adapter.removeOne,
                    removeMany: adapter.removeMany,
                    movePriority: (s, { payload: { id, priority, parentFilter } }) => {
                        // Get IDs and insert our item at the new index
                        var affectedIds = lodash_1.default.orderBy(lodash_1.default.filter(lodash_1.default.values(s.entities), parentFilter).filter(e => e.id !== id), 'priority').map(e => e.id);
                        affectedIds.splice(priority, 0, id);
                        // Apply update
                        affectedIds.forEach((id, i) => s.entities[id].priority = i);
                    }
                }
            }).reducer];
    }));
}
function createJasonReducers(schema) {
    return generateSlices(lodash_1.default.keys(schema));
}
exports.default = createJasonReducers;
