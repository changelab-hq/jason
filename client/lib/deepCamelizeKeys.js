"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const lodash_1 = __importDefault(require("lodash"));
function deepCamelizeKeys(item, excludeIf = k => false) {
    function camelizeKey(key) {
        if (excludeIf(key))
            return key;
        return lodash_1.default.camelCase(key);
    }
    if (lodash_1.default.isArray(item)) {
        return lodash_1.default.map(item, item => deepCamelizeKeys(item, excludeIf));
    }
    else if (lodash_1.default.isObject(item)) {
        return lodash_1.default.mapValues(lodash_1.default.mapKeys(item, (v, k) => camelizeKey(k)), (v, k) => deepCamelizeKeys(v, excludeIf));
    }
    else {
        return item;
    }
}
exports.default = deepCamelizeKeys;
