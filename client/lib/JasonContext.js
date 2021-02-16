"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const react_1 = require("react");
const eager = function (entity, id, relations) {
    console.error("Eager called but is not implemented");
};
const context = react_1.createContext({ actions: {}, subscribe: null, eager });
exports.default = context;
