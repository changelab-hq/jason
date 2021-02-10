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
            console.debug({ schema });
            const serverActionQueue = createServerActionQueue_1.default();
            const consumer = actioncable_1.createConsumer();
            const allReducers = Object.assign(Object.assign({}, reducers), createJasonReducers_1.default(schema));
            console.debug({ allReducers });
            const store = toolkit_1.configureStore({ reducer: allReducers, middleware: [...middleware, pruneIdsMiddleware_1.default(schema)] });
            const dispatch = store.dispatch;
            const optDis = createOptDis_1.default(schema, dispatch, restClient_1.default, serverActionQueue);
            const actions = createActions_1.default(schema, store, restClient_1.default, optDis, extraActions);
            const eager = makeEager_1.default(schema);
            let payloadHandlers = {};
            let configs = {};
            let subOptions = {};
            function handlePayload(payload) {
                const { md5Hash } = payload;
                const handler = payloadHandlers[md5Hash];
                if (handler) {
                    handler(payload);
                }
                else {
                    console.warn("Payload arrived with no handler", payload, payloadHandlers);
                }
            }
            const subscription = (consumer.subscriptions.create({
                channel: 'Jason::Channel'
            }, {
                connected: () => {
                    setConnected(true);
                    dispatch({ type: 'jason/upsert', payload: { connected: true } });
                    console.debug('Connected to ActionCable');
                    // When AC loses connection - all state is lost, so we need to re-initialize all subscriptions
                    lodash_1.default.keys(configs).forEach(md5Hash => createSubscription(configs[md5Hash], subOptions[md5Hash]));
                },
                received: payload => {
                    handlePayload(payload);
                    console.debug("ActionCable Payload received: ", payload);
                },
                disconnected: () => {
                    setConnected(false);
                    dispatch({ type: 'jason/upsert', payload: { connected: false } });
                    console.warn('Disconnected from ActionCable');
                }
            }));
            function createSubscription(config, options = {}) {
                // We need the hash to be consistent in Ruby / Javascript
                const hashableConfig = lodash_1.default(Object.assign({ conditions: {}, includes: {} }, config)).toPairs().sortBy(0).fromPairs().value();
                const md5Hash = blueimp_md5_1.default(JSON.stringify(hashableConfig));
                payloadHandlers[md5Hash] = createPayloadHandler_1.default({ dispatch, serverActionQueue, subscription, config });
                configs[md5Hash] = hashableConfig;
                subOptions[md5Hash] = options;
                setTimeout(() => subscription.send({ createSubscription: hashableConfig }), 500);
                let pollInterval = null;
                console.log("createSubscription", { config, options });
                // This is only for debugging / dev - not prod!
                // @ts-ignore
                if (options.pollInterval) {
                    // @ts-ignore
                    pollInterval = setInterval(() => subscription.send({ getPayload: config, forceRefresh: true }), options.pollInterval);
                }
                return {
                    remove() {
                        removeSubscription(hashableConfig);
                        if (pollInterval)
                            clearInterval(pollInterval);
                    },
                    md5Hash
                };
            }
            function removeSubscription(config) {
                subscription.send({ removeSubscription: config });
                const md5Hash = blueimp_md5_1.default(JSON.stringify(config));
                delete payloadHandlers[md5Hash];
                delete configs[md5Hash];
                delete subOptions[md5Hash];
            }
            setValue({
                actions: actions,
                subscribe: createSubscription,
                eager,
                handlePayload
            });
            setStore(store);
        });
    }, []);
    return [store, value, connected];
}
exports.default = useJason;
