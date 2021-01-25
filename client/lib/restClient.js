"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
var _a;
Object.defineProperty(exports, "__esModule", { value: true });
const axios_1 = __importDefault(require("axios"));
const axios_case_converter_1 = __importDefault(require("axios-case-converter"));
const uuid_1 = require("uuid");
const csrfToken = (_a = document === null || document === void 0 ? void 0 : document.querySelector("meta[name=csrf-token]")) === null || _a === void 0 ? void 0 : _a.content;
axios_1.default.defaults.headers.common['X-CSRF-Token'] = csrfToken;
const restClient = axios_case_converter_1.default(axios_1.default.create(), {
    preservedKeys: (key) => {
        return uuid_1.validate(key);
    }
});
exports.default = restClient;
