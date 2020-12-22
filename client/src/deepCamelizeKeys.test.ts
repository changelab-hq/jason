import deepCamelizeKeys from './deepCamelizeKeys'

test('scalar number', () => {
  expect(deepCamelizeKeys(1)).toBe(1)
})

test('scalar number float', () => {
  expect(deepCamelizeKeys(1.123)).toBe(1.123)
})

test('scalar string', () => {
  expect(deepCamelizeKeys('test')).toBe('test')
})

test('scalar null', () => {
  expect(deepCamelizeKeys(null)).toBe(null)
})

test('scalar boolean', () => {
  expect(deepCamelizeKeys(true)).toBe(true)
})

test('object with existing camelized keys', () => {
  expect(deepCamelizeKeys({ testMe: 'test' })).toStrictEqual({ testMe: 'test' })
})

test('array with existing camelized keys', () => {
  expect(deepCamelizeKeys([{ testMe: 'test' }, { testMe2: 'test' }])).toStrictEqual([{ testMe: 'test' }, { testMe2: 'test' }])
})

test('object with mixed keys', () => {
  expect(deepCamelizeKeys({ testMe: 'test', test_2: 'dog', test_me2: true })).toStrictEqual({ testMe: 'test', test2: 'dog', testMe2: true })
})

test('array with mixed keys', () => {
  expect(deepCamelizeKeys([
    { testMe: 'test', test_2: 'dog', test_me2: true },
    { testMe3: 'test', test_3: 'dog', test_me4: true }
  ])).toStrictEqual([
    { testMe: 'test', test2: 'dog', testMe2: true },
    { testMe3: 'test', test3: 'dog', testMe4: true }
  ])
})

test('nested with object at top level', () => {
  expect(deepCamelizeKeys({
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
  })
})

test('nested with object at top level', () => {
  expect(deepCamelizeKeys([{
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
  }])
})

test('excludes keys by function', () => {
  expect(deepCamelizeKeys({
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
  })
})
