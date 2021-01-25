import { renderHook, act } from '@testing-library/react-hooks'
import useJason from './useJason'
import restClient from './restClient'

jest.mock('./restClient')

test('it works', async () => {
  const resp = { data: { post: {} } };
  // @ts-ignore
  restClient.get.mockResolvedValue(resp);

  const { result, waitForNextUpdate } = renderHook(() => useJason({ reducers: {
    test: (s,a) => s || {}
  }}));

  await waitForNextUpdate()
  const [store, value, connected] = result.current
  const { handlePayload, subscribe } = value

  const subscription = subscribe({ post: {} })

  handlePayload({
    type: 'payload',
    model: 'post',
    payload: [{ id: 4, name: 'test' }],
    md5Hash: subscription.md5Hash,
    idx: 1
  })

  handlePayload({
    id: 4,
    model: 'post',
    destroy: true,
    md5Hash: subscription.md5Hash,
    idx: 2
  })

  handlePayload({
    id: 5,
    model: 'post',
    payload: { id: 5, name: 'test2' },
    md5Hash: subscription.md5Hash,
    idx: 3
  })
})

test('pruning IDs', async () => {
  const resp = { data: { post: {} } };

  // @ts-ignore
  restClient.get.mockResolvedValue(resp);

  const { result, waitForNextUpdate } = renderHook(() => useJason({ reducers: {
    test: (s,a) => s || {}
  }}));

  await waitForNextUpdate()
  const [store, value, connected] = result.current
  const { handlePayload, subscribe } = value

  const subscription = subscribe({ post: {} })

  handlePayload({
    type: 'payload',
    model: 'post',
    payload: [{ id: 4, name: 'test' }],
    md5Hash: subscription.md5Hash,
    idx: 1
  })

  handlePayload({
    type: 'payload',
    model: 'post',
    payload: [{ id: 5, name: 'test it out' }],
    md5Hash: subscription.md5Hash,
    idx: 2
  })

  // The ID 4 should have been pruned
  expect(store.getState().posts.ids).toStrictEqual([5])
})