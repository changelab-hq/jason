"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const pusher_js_1 = __importDefault(require("pusher-js"));
const restClient_1 = __importDefault(require("../restClient"));
const uuid_1 = require("uuid");
const lodash_1 = __importDefault(require("lodash"));
function pusherAdapter(jasonConfig, handlePayload, dispatch) {
    let consumerId = uuid_1.v4();
    const { pusherKey, pusherRegion, pusherChannelPrefix } = jasonConfig;
    const pusher = new pusher_js_1.default(pusherKey, {
        cluster: 'eu',
        forceTLS: true,
        authEndpoint: '/jason/api/pusher/auth'
    });
    pusher.connection.bind('state_change', ({ current }) => {
        if (current === 'connected') {
            dispatch({ type: 'jason/upsert', payload: { connected: true } });
        }
        else {
            dispatch({ type: 'jason/upsert', payload: { connected: false } });
        }
    });
    pusher.connection.bind('error', error => {
        dispatch({ type: 'jason/upsert', payload: { connected: false } });
    });
    const configToChannel = {};
    function createSubscription(config) {
        restClient_1.default.post('/jason/api/create_subscription', { config, consumerId })
            .then(({ data: { channelName } }) => {
            configToChannel[JSON.stringify(config)] = channelName;
            subscribeToChannel(channelName);
        })
            .catch(e => console.error(e));
    }
    function removeSubscription(config) {
        const channelName = configToChannel[JSON.stringify(config)];
        unsubscribeFromChannel(fullChannelName(channelName));
        restClient_1.default.post('/jason/api/remove_subscription', { config, consumerId })
            .catch(e => console.error(e));
    }
    function getPayload(config, options) {
        restClient_1.default.post('/jason/api/get_payload', {
            config,
            options
        })
            .then(({ data }) => {
            lodash_1.default.map(data, (payload, modelName) => {
                handlePayload(payload);
            });
        })
            .catch(e => console.error(e));
    }
    function subscribeToChannel(channelName) {
        const channel = pusher.subscribe(fullChannelName(channelName));
        channel.bind('changed', message => handlePayload(message));
    }
    function unsubscribeFromChannel(channelName) {
        const channel = pusher.unsubscribe(fullChannelName(channelName));
    }
    function fullChannelName(channelName) {
        return `private-${pusherChannelPrefix}-${channelName}`;
    }
    return { getPayload, createSubscription, removeSubscription };
}
exports.default = pusherAdapter;
