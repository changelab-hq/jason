"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const pluralize_1 = __importDefault(require("pluralize"));
const lodash_1 = __importDefault(require("lodash"));
function addRelations(s, objects, objectType, relations, suffix = '') {
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
        else if (lodash_1.default.isObject(objects)) {
            const relatedObjects = lodash_1.default.values(s[pluralize_1.default(relation) + suffix].entities);
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
exports.default = addRelations;
