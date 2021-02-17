"use strict";
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const react_hooks_1 = require("@testing-library/react-hooks");
const useJason_1 = __importDefault(require("./useJason"));
const restClient_1 = __importDefault(require("./restClient"));
jest.mock('./restClient');
test('it works', () => __awaiter(void 0, void 0, void 0, function* () {
    const resp = { data: {
            schema: { post: {} },
            transportService: 'action_cable'
        } };
    // @ts-ignore
    restClient_1.default.get.mockResolvedValue(resp);
    const { result, waitForNextUpdate } = react_hooks_1.renderHook(() => useJason_1.default({ reducers: {
            test: (s, a) => s || {}
        } }));
    yield waitForNextUpdate();
    const [store, value, connected] = result.current;
    const { handlePayload, subscribe } = value;
    const subscription = subscribe({ post: {} });
    handlePayload({
        type: 'payload',
        model: 'post',
        payload: [{ id: 4, name: 'test' }],
        md5Hash: subscription.md5Hash,
        idx: 1
    });
    handlePayload({
        id: 4,
        model: 'post',
        destroy: true,
        md5Hash: subscription.md5Hash,
        idx: 2
    });
    handlePayload({
        id: 5,
        model: 'post',
        payload: { id: 5, name: 'test2' },
        md5Hash: subscription.md5Hash,
        idx: 3
    });
}));
test('pruning IDs', () => __awaiter(void 0, void 0, void 0, function* () {
    const resp = { data: {
            schema: { post: {} },
            transportService: 'action_cable'
        } };
    // @ts-ignore
    restClient_1.default.get.mockResolvedValue(resp);
    const { result, waitForNextUpdate } = react_hooks_1.renderHook(() => useJason_1.default({ reducers: {
            test: (s, a) => s || {}
        } }));
    yield waitForNextUpdate();
    const [store, value, connected] = result.current;
    const { handlePayload, subscribe } = value;
    const subscription = subscribe({ post: {} });
    handlePayload({
        type: 'payload',
        model: 'post',
        payload: [{ id: 4, name: 'test' }],
        md5Hash: subscription.md5Hash,
        idx: 1
    });
    handlePayload({
        type: 'payload',
        model: 'post',
        payload: [{ id: 5, name: 'test it out' }],
        md5Hash: subscription.md5Hash,
        idx: 2
    });
    // The ID 4 should have been pruned
    expect(store.getState().posts.ids).toStrictEqual(['5']);
}));
test('pruning IDs by destroy', () => __awaiter(void 0, void 0, void 0, function* () {
    const resp = { data: {
            schema: { post: {} },
            transportService: 'action_cable'
        } };
    // @ts-ignore
    restClient_1.default.get.mockResolvedValue(resp);
    const { result, waitForNextUpdate } = react_hooks_1.renderHook(() => useJason_1.default({ reducers: {
            test: (s, a) => s || {}
        } }));
    yield waitForNextUpdate();
    const [store, value, connected] = result.current;
    const { handlePayload, subscribe } = value;
    const subscription = subscribe({ post: {} });
    handlePayload({
        type: 'payload',
        model: 'post',
        payload: [{ id: 4, name: 'test' }, { id: 5, name: 'test it out' }],
        md5Hash: subscription.md5Hash,
        idx: 1
    });
    expect(store.getState().posts.ids).toStrictEqual(['4', '5']);
    handlePayload({
        destroy: true,
        model: 'post',
        id: 5,
        md5Hash: subscription.md5Hash,
        idx: 2
    });
    // The ID 4 should have been pruned
    expect(store.getState().posts.ids).toStrictEqual(['4']);
}));
