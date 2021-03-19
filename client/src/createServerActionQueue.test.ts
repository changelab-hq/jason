import createServerActionQueue from './createServerActionQueue'

test('Adding items', () => {
  const serverActionQueue = createServerActionQueue()
  serverActionQueue.addItem({ type: 'entity/add', payload: { id: 'abc', attribute: 1 } })
  const item = serverActionQueue.getItem()
  expect(item.action).toStrictEqual({ type: 'entity/add', payload: { id: 'abc', attribute: 1 } })
})

test('Deduping of items that will overwrite each other', () => {
  const serverActionQueue = createServerActionQueue()
  serverActionQueue.addItem({ type: 'entity/upsert', payload: { id: 'abc', attribute: 1 } })
  serverActionQueue.addItem({ type: 'entity/upsert', payload: { id: 'abc', attribute: 2 } })
  serverActionQueue.addItem({ type: 'entity/upsert', payload: { id: 'abc', attribute: 3 } })

  const item = serverActionQueue.getItem()

  expect(item.action).toStrictEqual({ type: 'entity/upsert', payload: { id: 'abc', attribute: 3 } })
})

test('Deduping of items with a superset', () => {
  const serverActionQueue = createServerActionQueue()
  serverActionQueue.addItem({ type: 'entity/upsert', payload: { id: 'abc', attribute: 1 } })
  serverActionQueue.addItem({ type: 'entity/upsert', payload: { id: 'abc', attribute: 2, attribute2: 'test' } })

  const item = serverActionQueue.getItem()

  expect(item.action).toStrictEqual({ type: 'entity/upsert', payload: { id: 'abc', attribute: 2, attribute2: 'test' } })
})

test("doesn't dedupe items with some attributes missing", () => {
  const serverActionQueue = createServerActionQueue()
  serverActionQueue.addItem({ type: 'entity/upsert', payload: { id: 'abc', attribute: 1 } })
  serverActionQueue.addItem({ type: 'entity/upsert', payload: { id: 'abc', attribute2: 'test' } })

  const item = serverActionQueue.getItem()
  serverActionQueue.itemProcessed(item.id)
  const item2 = serverActionQueue.getItem()

  expect(item.action).toStrictEqual({ type: 'entity/upsert', payload: { id: 'abc', attribute: 1 } })
  expect(item2.action).toStrictEqual({ type: 'entity/upsert', payload: { id: 'abc', attribute2: 'test' } })
})

test("executes success callback", async function() {
  const serverActionQueue = createServerActionQueue()
  let cb = ''
  let data = ''

  // Check it can resolve chained promises
  const promise = serverActionQueue.addItem({ type: 'entity/upsert', payload: { id: 'abc', attribute: 1 } })
  .then(d => data = d)
  .then(() => cb = 'resolved')

  const item = serverActionQueue.getItem()
  serverActionQueue.itemProcessed(item.id, 'testdata');

  await promise
  expect(data).toEqual('testdata')
  expect(cb).toEqual('resolved')
})

test("executes error callback", async function() {
  const serverActionQueue = createServerActionQueue()
  let cb = ''
  let error = ''

  // Check it can resolve chained promises
  const promise = serverActionQueue.addItem({ type: 'entity/upsert', payload: { id: 'abc', attribute: 1 } })
  .then(() => cb = 'resolved')
  .catch(e => error = e)

  const item = serverActionQueue.getItem()
  serverActionQueue.itemFailed(item.id, 'testerror');

  await promise
  expect(cb).toEqual('')
  expect(error).toEqual('testerror')
})


test("merges success callbacks", async function() {
  const results: any[] = []

  const serverActionQueue = createServerActionQueue()
  const p1 = serverActionQueue.addItem({ type: 'entity/upsert', payload: { id: 'abc', attribute: 1 } })
  .then(data => results.push(data))

  const p2 = serverActionQueue.addItem({ type: 'entity/upsert', payload: { id: 'abc', attribute: 2, attribute2: 'test' } })
  .then(data => results.push(data))

  const item = serverActionQueue.getItem()
  serverActionQueue.itemProcessed(item.id, 'complete')

  await Promise.all([p1,p2])
  expect(results).toEqual(['complete', 'complete'])
})