"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const lodash_1 = __importDefault(require("lodash"));
const react_redux_1 = require("react-redux");
const addRelations_1 = __importDefault(require("./addRelations"));
function useEager(entity, id = null, relations = []) {
    if (id) {
        return react_redux_1.useSelector(s => addRelations_1.default(s, Object.assign({}, s[entity].entities[String(id)]), entity, relations), lodash_1.default.isEqual);
    }
    else {
        return react_redux_1.useSelector(s => addRelations_1.default(s, lodash_1.default.values(s[entity].entities), entity, relations), lodash_1.default.isEqual);
    }
}
exports.default = useEager;
