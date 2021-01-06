"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    Object.defineProperty(o, k2, { enumerable: true, get: function() { return m[k]; } });
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || function (mod) {
    if (mod && mod.__esModule) return mod;
    var result = {};
    if (mod != null) for (var k in mod) if (k !== "default" && Object.prototype.hasOwnProperty.call(mod, k)) __createBinding(result, mod, k);
    __setModuleDefault(result, mod);
    return result;
};
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const createActions_1 = __importDefault(require("./createActions"));
const createJasonReducers_1 = __importDefault(require("./createJasonReducers"));
const createPayloadHandler_1 = __importDefault(require("./createPayloadHandler"));
const createOptDis_1 = __importDefault(require("./createOptDis"));
const createServerActionQueue_1 = __importDefault(require("./createServerActionQueue"));
const actioncable_1 = require("@rails/actioncable");
const JasonContext_1 = __importDefault(require("./JasonContext"));
const axios_1 = __importDefault(require("axios"));
const axios_case_converter_1 = __importDefault(require("axios-case-converter"));
const react_redux_1 = require("react-redux");
const toolkit_1 = require("@reduxjs/toolkit");
const makeEager_1 = __importDefault(require("./makeEager"));
const humps_1 = require("humps");
const blueimp_md5_1 = __importDefault(require("blueimp-md5"));
const lodash_1 = __importDefault(require("lodash"));
const react_1 = __importStar(require("react"));
const uuid_1 = require("uuid");
const JasonProvider = ({ reducers, middleware, extraActions, children }) => {
    const [store, setStore] = react_1.useState(null);
    const [value, setValue] = react_1.useState(null);
    const [connected, setConnected] = react_1.useState(false);
    const csrfToken = document.querySelector("meta[name=csrf-token]").content;
    axios_1.default.defaults.headers.common['X-CSRF-Token'] = csrfToken;
    const restClient = axios_case_converter_1.default(axios_1.default.create(), {
        preservedKeys: (key) => {
            return uuid_1.validate(key);
        }
    });
    react_1.useEffect(() => {
        restClient.get('/jason/api/schema')
            .then(({ data: snakey_schema }) => {
            const schema = humps_1.camelizeKeys(snakey_schema);
            const serverActionQueue = createServerActionQueue_1.default();
            const consumer = actioncable_1.createConsumer();
            const allReducers = Object.assign(Object.assign({}, reducers), createJasonReducers_1.default(schema));
            console.log({ schema, allReducers });
            const store = toolkit_1.configureStore({ reducer: allReducers, middleware });
            let payloadHandlers = {};
            function handlePayload(payload) {
                const { model, md5Hash } = payload;
                console.log({ md5Hash, fn: `${model}:${md5Hash}`, payloadHandlers, model: lodash_1.default.camelCase(model), payload });
                const handler = payloadHandlers[`${lodash_1.default.camelCase(model)}:${md5Hash}`];
                if (handler) {
                    handler(Object.assign(Object.assign({}, payload), { model: lodash_1.default.camelCase(model) }));
                }
            }
            const subscription = (consumer.subscriptions.create({
                channel: 'Jason::Channel'
            }, {
                connected: () => {
                    setConnected(true);
                },
                received: payload => {
                    console.log("Payload received", payload);
                    handlePayload(payload);
                },
                disconnected: () => console.warn('Disconnected from ActionCable')
            }));
            console.log('sending message');
            subscription.send({ message: 'test' });
            function createSubscription(config) {
                const md5Hash = blueimp_md5_1.default(JSON.stringify(config));
                console.log('Subscribe with', config, md5Hash);
                lodash_1.default.map(config, (v, model) => {
                    payloadHandlers[`${model}:${md5Hash}`] = createPayloadHandler_1.default(store.dispatch, serverActionQueue, subscription, model, schema[model]);
                });
                subscription.send({ createSubscription: config });
                return () => removeSubscription(config);
            }
            function removeSubscription(config) {
                subscription.send({ removeSubscription: config });
                const md5Hash = blueimp_md5_1.default(JSON.stringify(config));
                lodash_1.default.map(config, (v, model) => {
                    delete payloadHandlers[`${model}:${md5Hash}`];
                });
            }
            const optDis = createOptDis_1.default(schema, store.dispatch, restClient, serverActionQueue);
            const actions = createActions_1.default(schema, store, restClient, optDis, extraActions);
            const eager = makeEager_1.default(schema);
            console.log({ actions });
            setValue({
                actions: actions,
                subscribe: (config) => createSubscription(config),
                eager
            });
            setStore(store);
        });
    }, []);
    if (!(store && value && connected))
        return react_1.default.createElement("div", null); // Wait for async fetch of schema to complete
    return react_1.default.createElement(react_redux_1.Provider, { store: store },
        react_1.default.createElement(JasonContext_1.default.Provider, { value: value }, children));
};
exports.default = JasonProvider;
