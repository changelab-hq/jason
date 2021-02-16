"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const JasonContext_1 = __importDefault(require("./JasonContext"));
const react_1 = require("react");
function useEager(entity, id = null, relations = []) {
    const { eager } = react_1.useContext(JasonContext_1.default);
    return eager(entity, id, relations);
}
exports.default = useEager;
