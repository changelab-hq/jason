import Pusher from 'pusher-js'
import restClient from '../restClient'
import { v4 as uuidv4 } from 'uuid'
import _ from 'lodash'

export default function pusherAdapter(jasonConfig, handlePayload, dispatch) {
  const consumerId = uuidv4()

  const { pusherHost, pusherKey, pusherRegion, pusherChannelPrefix } = jasonConfig
  let config : any = {
    cluster: pusherRegion,
    forceTLS: true,
    authEndpoint: '/jason/api/pusher/auth',
  }
  if (pusherHost) {
    config = {
      ...config,
      wsHost: pusherHost,
      httpHost: pusherHost,
    }
  }
  const pusher = new Pusher(pusherKey, config)
  pusher.connection.bind('state_change', ({ current }) => {
    if (current === 'connected') {
      dispatch({ type: 'jason/upsert', payload: { connected: true } })
    } else {
      dispatch({ type: 'jason/upsert', payload: { connected: false } })
    }
  })
  pusher.connection.bind( 'error', error => {
    dispatch({ type: 'jason/upsert', payload: { connected: false } })
  });

  const configToChannel = {}

  function createSubscription(config) {
    restClient.post('/jason/api/create_subscription', { config, consumerId })
    .then(({ data: { channelName } }) => {
      configToChannel[JSON.stringify(config)] = channelName
      subscribeToChannel(channelName)
    })
    .catch(e => console.error(e))
  }

  function removeSubscription(config) {
    const channelName = configToChannel[JSON.stringify(config)]
    unsubscribeFromChannel(fullChannelName(channelName))
    restClient.post('/jason/api/remove_subscription', { config, consumerId })
    .catch(e => console.error(e))
  }

  function getPayload(config, options) {
    restClient.post('/jason/api/get_payload', {
      config,
      options
    })
    .then(({ data }) => {
      _.map(data, (payload, modelName) => {
        handlePayload(payload)
      })
    })
    .catch(e => console.error(e))
  }

  function subscribeToChannel(channelName) {
    const channel = pusher.subscribe(fullChannelName(channelName))
    channel.bind('changed', message => handlePayload(message))
  }

  function unsubscribeFromChannel(channelName) {
    const channel = pusher.unsubscribe(fullChannelName(channelName))
  }

  function fullChannelName(channelName) {
    return `private-${pusherChannelPrefix}-${channelName}`
  }

  return { getPayload, createSubscription, removeSubscription }
}
