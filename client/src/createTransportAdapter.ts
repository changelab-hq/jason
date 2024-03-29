import actionCableAdapter from './transportAdapters/actionCableAdapter'
import pusherAdapter from './transportAdapters/pusherAdapter'

export default function createTransportAdapter(jasonConfig, handlePayload, dispatch, onConnect, transportOptions) {
  const { transportService } = jasonConfig
  if (transportService === 'action_cable') {
    return actionCableAdapter(jasonConfig, handlePayload, dispatch, onConnect, transportOptions)
  } else if (transportService === 'pusher') {
    return pusherAdapter(jasonConfig, handlePayload, dispatch)
  } else {
    throw(`Transport adapter does not exist for ${transportService}`)
  }
}