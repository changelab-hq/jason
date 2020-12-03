"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const createActions_1 = require("./createActions");
const actioncable_1 = require("@rails/actioncable");
const JasonContext_1 = require("./JasonContext");
const axios_1 = require("axios");
const axios_case_converter_1 = require("axios-case-converter");
const react_redux_1 = require("react-redux");
const toolkit_1 = require("@reduxjs/toolkit");
const createJasonReducers_1 = require("./createJasonReducers");
const createPayloadHandler_1 = require("./createPayloadHandler");
const makeEager_1 = require("./makeEager");
const humps_1 = require("humps");
const blueimp_md5_1 = require("blueimp-md5");
const lodash_1 = require("lodash");
const react_1 = require("react");
const JasonProvider = ({ reducers, middleware, extraActions, children }) => {
    const [store, setStore] = react_1.useState(null);
    const [value, setValue] = react_1.useState(null);
    const [connected, setConnected] = react_1.useState(false);
    const csrfToken = document.querySelector("meta[name=csrf-token]").content;
    axios_1.default.defaults.headers.common['X-CSRF-Token'] = csrfToken;
    const restClient = axios_case_converter_1.default(axios_1.default.create());
    react_1.useEffect(() => {
        restClient.get('/jason/api/schema')
            .then(({ data: snakey_schema }) => {
            const schema = humps_1.camelizeKeys(snakey_schema);
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
                    payloadHandlers[`${model}:${md5Hash}`] = createPayloadHandler_1.default(store.dispatch, subscription, model, schema[model]);
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
            const actions = createActions_1.default(schema, store, restClient, extraActions);
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
