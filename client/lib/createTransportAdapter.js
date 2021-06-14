"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const actionCableAdapter_1 = __importDefault(require("./transportAdapters/actionCableAdapter"));
const pusherAdapter_1 = __importDefault(require("./transportAdapters/pusherAdapter"));
function createTransportAdapter(jasonConfig, handlePayload, dispatch, onConnect, transportOptions) {
    const { transportService } = jasonConfig;
    if (transportService === 'action_cable') {
        return actionCableAdapter_1.default(jasonConfig, handlePayload, dispatch, onConnect, transportOptions);
    }
    else if (transportService === 'pusher') {
        return pusherAdapter_1.default(jasonConfig, handlePayload, dispatch);
    }
    else {
        throw (`Transport adapter does not exist for ${transportService}`);
    }
}
exports.default = createTransportAdapter;
