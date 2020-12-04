"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const pluralize_1 = __importDefault(require("pluralize"));
const lodash_1 = __importDefault(require("lodash"));
const react_redux_1 = require("react-redux");
function default_1(schema) {
    function addRelations(s, objects, objectType, relations) {
        // first find out relation name
        if (lodash_1.default.isArray(relations)) {
            relations.forEach(relation => {
                objects = addRelations(s, objects, objectType, relation);
            });
        }
        else if (typeof (relations) === 'object') {
            const relation = Object.keys(relations)[0];
            const subRelations = relations[relation];
            objects = addRelations(s, objects, objectType, relation);
            objects[relation] = addRelations(s, objects[relation], pluralize_1.default(relation), subRelations);
            // #
        }
        else if (typeof (relations) === 'string') {
            const relation = relations;
            if (lodash_1.default.isArray(objects)) {
                objects = objects.map(obj => addRelations(s, obj, objectType, relation));
            }
            else {
                const relatedObjects = lodash_1.default.values(s[pluralize_1.default(relation)].entities);
                if (pluralize_1.default.isSingular(relation)) {
                    objects = Object.assign(Object.assign({}, objects), { [relation]: lodash_1.default.find(relatedObjects, { id: objects[relation + 'Id'] }) });
                }
                else {
                    objects = Object.assign(Object.assign({}, objects), { [relation]: relatedObjects.filter(e => e[pluralize_1.default.singular(objectType) + 'Id'] === objects.id) });
                }
            }
        }
        return objects;
    }
    function useEager(entity, id = null, relations = []) {
        if (id) {
            return react_redux_1.useSelector(s => addRelations(s, Object.assign({}, s[entity].entities[String(id)]), entity, relations));
        }
        else {
            return react_redux_1.useSelector(s => addRelations(s, lodash_1.default.values(s[entity].entities), entity, relations));
        }
    }
    return useEager;
}
exports.default = default_1;
