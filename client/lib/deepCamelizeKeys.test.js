"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const deepCamelizeKeys_1 = __importDefault(require("./deepCamelizeKeys"));
test('scalar number', () => {
    expect(deepCamelizeKeys_1.default(1)).toBe(1);
});
test('scalar number float', () => {
    expect(deepCamelizeKeys_1.default(1.123)).toBe(1.123);
});
test('scalar string', () => {
    expect(deepCamelizeKeys_1.default('test')).toBe('test');
});
test('scalar null', () => {
    expect(deepCamelizeKeys_1.default(null)).toBe(null);
});
test('scalar boolean', () => {
    expect(deepCamelizeKeys_1.default(true)).toBe(true);
});
test('object with existing camelized keys', () => {
    expect(deepCamelizeKeys_1.default({ testMe: 'test' })).toStrictEqual({ testMe: 'test' });
});
test('array with existing camelized keys', () => {
    expect(deepCamelizeKeys_1.default([{ testMe: 'test' }, { testMe2: 'test' }])).toStrictEqual([{ testMe: 'test' }, { testMe2: 'test' }]);
});
test('object with mixed keys', () => {
    expect(deepCamelizeKeys_1.default({ testMe: 'test', test_2: 'dog', test_me2: true })).toStrictEqual({ testMe: 'test', test2: 'dog', testMe2: true });
});
test('array with mixed keys', () => {
    expect(deepCamelizeKeys_1.default([
        { testMe: 'test', test_2: 'dog', test_me2: true },
        { testMe3: 'test', test_3: 'dog', test_me4: true }
    ])).toStrictEqual([
        { testMe: 'test', test2: 'dog', testMe2: true },
        { testMe3: 'test', test3: 'dog', testMe4: true }
    ]);
});
test('nested with object at top level', () => {
    expect(deepCamelizeKeys_1.default({
        test_me: {
            test_me2: {
                test_me3: [
                    { test_it_out: '49' },
                    { test_fun: 'what' }
                ]
            }
        }
    })).toStrictEqual({
        testMe: {
            testMe2: {
                testMe3: [
                    { testItOut: '49' },
                    { testFun: 'what' }
                ]
            }
        }
    });
});
test('nested with object at top level', () => {
    expect(deepCamelizeKeys_1.default([{
            test_me: {
                test_me2: {
                    test_me3: [
                        { test_it_out: '49' },
                        { test_fun: 'what' }
                    ]
                }
            }
        }, {
            test_it52: 'what?'
        }])).toStrictEqual([{
            testMe: {
                testMe2: {
                    testMe3: [
                        { testItOut: '49' },
                        { testFun: 'what' }
                    ]
                }
            }
        }, {
            testIt52: 'what?'
        }]);
});
test('excludes keys by function', () => {
    expect(deepCamelizeKeys_1.default({
        test_me: {
            test_me2: {
                test_me3: [
                    { test_it_out: '49' },
                    { test_fun: 'what' }
                ]
            }
        }
    }, k => (k === 'test_me2'))).toStrictEqual({
        testMe: {
            test_me2: {
                testMe3: [
                    { testItOut: '49' },
                    { testFun: 'what' }
                ]
            }
        }
    });
});
