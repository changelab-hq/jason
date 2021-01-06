"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const createServerActionQueue_1 = __importDefault(require("./createServerActionQueue"));
test('Adding items', () => {
    const serverActionQueue = createServerActionQueue_1.default();
    serverActionQueue.addItem({ type: 'entity/add', payload: { id: 'abc', attribute: 1 } });
    const item = serverActionQueue.getItem();
    expect(item).toStrictEqual({ type: 'entity/add', payload: { id: 'abc', attribute: 1 } });
});
test('Deduping of items that will overwrite each other', () => {
    const serverActionQueue = createServerActionQueue_1.default();
    serverActionQueue.addItem({ type: 'entity/upsert', payload: { id: 'abc', attribute: 1 } });
    serverActionQueue.addItem({ type: 'entity/upsert', payload: { id: 'abc', attribute: 2 } });
    serverActionQueue.addItem({ type: 'entity/upsert', payload: { id: 'abc', attribute: 3 } });
    const item = serverActionQueue.getItem();
    expect(item).toStrictEqual({ type: 'entity/upsert', payload: { id: 'abc', attribute: 3 } });
});
test('Deduping of items with a superset', () => {
    const serverActionQueue = createServerActionQueue_1.default();
    serverActionQueue.addItem({ type: 'entity/upsert', payload: { id: 'abc', attribute: 1 } });
    serverActionQueue.addItem({ type: 'entity/upsert', payload: { id: 'abc', attribute: 2, attribute2: 'test' } });
    const item = serverActionQueue.getItem();
    expect(item).toStrictEqual({ type: 'entity/upsert', payload: { id: 'abc', attribute: 2, attribute2: 'test' } });
});
test("doesn't dedupe items with some attributes missing", () => {
    const serverActionQueue = createServerActionQueue_1.default();
    serverActionQueue.addItem({ type: 'entity/upsert', payload: { id: 'abc', attribute: 1 } });
    serverActionQueue.addItem({ type: 'entity/upsert', payload: { id: 'abc', attribute2: 'test' } });
    const item = serverActionQueue.getItem();
    serverActionQueue.itemProcessed();
    const item2 = serverActionQueue.getItem();
    expect(item).toStrictEqual({ type: 'entity/upsert', payload: { id: 'abc', attribute: 1 } });
    expect(item2).toStrictEqual({ type: 'entity/upsert', payload: { id: 'abc', attribute2: 'test' } });
});
