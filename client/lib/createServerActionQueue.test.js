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
const createServerActionQueue_1 = __importDefault(require("./createServerActionQueue"));
test('Adding items', () => {
    const serverActionQueue = createServerActionQueue_1.default();
    serverActionQueue.addItem({ type: 'entity/add', payload: { id: 'abc', attribute: 1 } });
    const item = serverActionQueue.getItem();
    expect(item.action).toStrictEqual({ type: 'entity/add', payload: { id: 'abc', attribute: 1 } });
});
test('Deduping of items that will overwrite each other', () => {
    const serverActionQueue = createServerActionQueue_1.default();
    serverActionQueue.addItem({ type: 'entity/upsert', payload: { id: 'abc', attribute: 1 } });
    serverActionQueue.addItem({ type: 'entity/upsert', payload: { id: 'abc', attribute: 2 } });
    serverActionQueue.addItem({ type: 'entity/upsert', payload: { id: 'abc', attribute: 3 } });
    const item = serverActionQueue.getItem();
    expect(item.action).toStrictEqual({ type: 'entity/upsert', payload: { id: 'abc', attribute: 3 } });
});
test('Deduping of items with a superset', () => {
    const serverActionQueue = createServerActionQueue_1.default();
    serverActionQueue.addItem({ type: 'entity/upsert', payload: { id: 'abc', attribute: 1 } });
    serverActionQueue.addItem({ type: 'entity/upsert', payload: { id: 'abc', attribute: 2, attribute2: 'test' } });
    const item = serverActionQueue.getItem();
    expect(item.action).toStrictEqual({ type: 'entity/upsert', payload: { id: 'abc', attribute: 2, attribute2: 'test' } });
});
test("doesn't dedupe items with some attributes missing", () => {
    const serverActionQueue = createServerActionQueue_1.default();
    serverActionQueue.addItem({ type: 'entity/upsert', payload: { id: 'abc', attribute: 1 } });
    serverActionQueue.addItem({ type: 'entity/upsert', payload: { id: 'abc', attribute2: 'test' } });
    const item = serverActionQueue.getItem();
    serverActionQueue.itemProcessed(item.id);
    const item2 = serverActionQueue.getItem();
    expect(item.action).toStrictEqual({ type: 'entity/upsert', payload: { id: 'abc', attribute: 1 } });
    expect(item2.action).toStrictEqual({ type: 'entity/upsert', payload: { id: 'abc', attribute2: 'test' } });
});
test("executes success callback", function () {
    return __awaiter(this, void 0, void 0, function* () {
        const serverActionQueue = createServerActionQueue_1.default();
        let cb = '';
        let data = '';
        // Check it can resolve chained promises
        const promise = serverActionQueue.addItem({ type: 'entity/upsert', payload: { id: 'abc', attribute: 1 } })
            .then(d => data = d)
            .then(() => cb = 'resolved');
        const item = serverActionQueue.getItem();
        serverActionQueue.itemProcessed(item.id, 'testdata');
        yield promise;
        expect(data).toEqual('testdata');
        expect(cb).toEqual('resolved');
    });
});
test("executes error callback", function () {
    return __awaiter(this, void 0, void 0, function* () {
        const serverActionQueue = createServerActionQueue_1.default();
        let cb = '';
        let error = '';
        // Check it can resolve chained promises
        const promise = serverActionQueue.addItem({ type: 'entity/upsert', payload: { id: 'abc', attribute: 1 } })
            .then(() => cb = 'resolved')
            .catch(e => error = e);
        const item = serverActionQueue.getItem();
        serverActionQueue.itemFailed(item.id, 'testerror');
        yield promise;
        expect(cb).toEqual('');
        expect(error).toEqual('testerror');
    });
});
test("merges success callbacks", function () {
    return __awaiter(this, void 0, void 0, function* () {
        const results = [];
        const serverActionQueue = createServerActionQueue_1.default();
        const p1 = serverActionQueue.addItem({ type: 'entity/upsert', payload: { id: 'abc', attribute: 1 } })
            .then(data => results.push(data));
        const p2 = serverActionQueue.addItem({ type: 'entity/upsert', payload: { id: 'abc', attribute: 2, attribute2: 'test' } })
            .then(data => results.push(data));
        const item = serverActionQueue.getItem();
        serverActionQueue.itemProcessed(item.id, 'complete');
        yield Promise.all([p1, p2]);
        expect(results).toEqual(['complete', 'complete']);
    });
});
