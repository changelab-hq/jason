"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const JasonContext_1 = require("./JasonContext");
const react_1 = require("react");
function useAct() {
    const { actions } = react_1.useContext(JasonContext_1.default);
    return actions;
}
exports.default = useAct;
