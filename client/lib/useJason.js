"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const createActions_1 = __importDefault(require("./createActions"));
const createJasonReducers_1 = __importDefault(require("./createJasonReducers"));
const createPayloadHandler_1 = __importDefault(require("./createPayloadHandler"));
const createOptDis_1 = __importDefault(require("./createOptDis"));
const createServerActionQueue_1 = __importDefault(require("./createServerActionQueue"));
const restClient_1 = __importDefault(require("./restClient"));
const pruneIdsMiddleware_1 = __importDefault(require("./pruneIdsMiddleware"));
const actioncable_1 = require("@rails/actioncable");
const toolkit_1 = require("@reduxjs/toolkit");
const makeEager_1 = __importDefault(require("./makeEager"));
const humps_1 = require("humps");
const blueimp_md5_1 = __importDefault(require("blueimp-md5"));
const lodash_1 = __importDefault(require("lodash"));
const react_1 = require("react");
function useJason({ reducers, middleware = [], extraActions }) {
    const [store, setStore] = react_1.useState(null);
    const [value, setValue] = react_1.useState(null);
    const [connected, setConnected] = react_1.useState(false);
    react_1.useEffect(() => {
        restClient_1.default.get('/jason/api/schema')
            .then(({ data: snakey_schema }) => {
            const schema = humps_1.camelizeKeys(snakey_schema);
            console.log({ schema });
            const serverActionQueue = createServerActionQueue_1.default();
            const consumer = actioncable_1.createConsumer();
            const allReducers = Object.assign(Object.assign({}, reducers), createJasonReducers_1.default(schema));
            console.log({ allReducers });
            const store = toolkit_1.configureStore({ reducer: allReducers, middleware: [...middleware, pruneIdsMiddleware_1.default(schema)] });
            let payloadHandlers = {};
            function handlePayload(payload) {
                const { model, md5Hash } = payload;
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
                    handlePayload(payload);
                },
                disconnected: () => {
                    setConnected(false);
                    console.warn('Disconnected from ActionCable');
                }
            }));
            function createSubscription(config) {
                const md5Hash = blueimp_md5_1.default(JSON.stringify(config));
                lodash_1.default.map(config, (v, model) => {
                    payloadHandlers[`${model}:${md5Hash}`] = createPayloadHandler_1.default(store.dispatch, serverActionQueue, subscription, model, schema[model], md5Hash);
                });
                subscription.send({ createSubscription: config });
                return {
                    remove: () => removeSubscription(config),
                    md5Hash
                };
            }
            function removeSubscription(config) {
                subscription.send({ removeSubscription: config });
                const md5Hash = blueimp_md5_1.default(JSON.stringify(config));
                lodash_1.default.map(config, (v, model) => {
                    delete payloadHandlers[`${model}:${md5Hash}`];
                });
            }
            const optDis = createOptDis_1.default(schema, store.dispatch, restClient_1.default, serverActionQueue);
            const actions = createActions_1.default(schema, store, restClient_1.default, optDis, extraActions);
            const eager = makeEager_1.default(schema);
            setValue({
                actions: actions,
                subscribe: (config) => createSubscription(config),
                eager,
                handlePayload
            });
            setStore(store);
        });
    }, []);
    return [store, value, connected];
}
exports.default = useJason;
