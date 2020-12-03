"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const JasonContext_1 = require("./JasonContext");
const react_1 = require("react");
function useSub(config) {
    const subscribe = react_1.useContext(JasonContext_1.default).subscribe;
    react_1.useEffect(() => {
        return subscribe(config);
    }, []);
}
exports.default = useSub;
