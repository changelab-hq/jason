"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const actioncable_1 = require("@rails/actioncable");
const restClient_1 = __importDefault(require("../restClient"));
const uuid_1 = require("uuid");
const lodash_1 = __importDefault(require("lodash"));
function actionCableAdapter(jasonConfig, handlePayload, dispatch, onConnected, transportOptions) {
    const consumerId = uuid_1.v4();
    const { cableUrl } = transportOptions;
    const consumer = cableUrl ? actioncable_1.createConsumer(cableUrl) : actioncable_1.createConsumer();
    const subscription = (consumer.subscriptions.create({
        channel: 'Jason::Channel'
    }, {
        connected: () => {
            dispatch({ type: 'jason/upsert', payload: { connected: true } });
            console.debug('Connected to ActionCable');
            // When AC loses connection - all state is lost, so we need to re-initialize all subscriptions
            onConnected();
        },
        received: payload => {
            handlePayload(payload);
            console.debug("ActionCable Payload received: ", payload);
        },
        disconnected: () => {
            dispatch({ type: 'jason/upsert', payload: { connected: false } });
            console.warn('Disconnected from ActionCable');
        }
    }));
    function createSubscription(config) {
        subscription.send({ createSubscription: config });
    }
    function removeSubscription(config) {
        restClient_1.default.post('/jason/api/remove_subscription', { config, consumerId })
            .catch(e => {
            console.error(e);
            Promise.reject(e);
        });
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
            .catch(e => {
            console.error(e);
            Promise.reject(e);
        });
    }
    function fullChannelName(channelName) {
        return channelName;
    }
    return { getPayload, createSubscription, removeSubscription };
}
exports.default = actionCableAdapter;
