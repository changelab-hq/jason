import jsonpatch from 'jsonpatch'
import { camelizeKeys } from 'humps'
import _ from lodash
import { createConsumer } from "@rails/actioncable"

window.cable = {
  consumer: createConsumer(),
  subscriptions: {}
}

function diffSeconds(dt2, dt1) {
  var diff =(dt2.getTime() - dt1.getTime()) / 1000
  return Math.abs(Math.round(diff))
}

export default function (config, callbacks) {
  var models = _.keys(config)

  var payloads = _.fromPairs(models.map(m => [m, []])); // []
  var idxs = _.fromPairs(models.map(m => [m, 0]));
  var patchQueues = _.fromPairs(models.map(m => [m, {}]));

  console.log({ models, config, patchQueues })

  var lastCheckAt = new Date();
  var updateDeadline = null;
  var checkInterval;
  var subscription;

  function getPayload() {
    console.log('GETTING PAYLOAD')
    subscription.send({ type: 'get_payload' })
  }

  const tGetPayload = _.throttle(getPayload, 10000)

  function processQueue(model) {
    lastCheckAt = new Date()
    if (patchQueues[model][idxs[model]]) {
      payloads[model] = jsonpatch.apply_patch(payloads[model], patchQueues[model][idxs[model]])
      if (patchQueues[model][idxs[model]].length > 0) {
        callbacks[model](_.fromPairs(camelizeKeys(payloads[model]).map(e => [e.id, e])))
      }
      delete patchQueues[model][idxs[model]]
      idxs[model]++
      updateDeadline = null
      processQueue(model)
    // If there are updates in the queue that are ahead of the index, some have arrived out of order
    // Set a deadline for new updates before it arrives.
    } else if (_.keys(patchQueues[model]).length > 0 && !updateDeadline) {
      var t = new Date()
      t.setSeconds(t.getSeconds() + 3)
      updateDeadline = t
      setTimeout(processQueue, 3100)
    // If more than 10 updates in queue, or deadline has passed, restart
    } else if (_.keys(patchQueues[model]).length > 10 || (updateDeadline && diffSeconds(updateDeadline, new Date()) < 0)) {
      tGetPayload()
      updateDeadline = null
    }
  }

  const { consumer } = window.cable

  subscription = consumer.subscriptions.create({
    channel: 'Jason::Channel',
    config: config
  }, {
    connected: () => { console.log('started here'); tGetPayload() },
    received: ((data) => {
      console.log({ data })
      const { type, models } = data
      _.map(models, (data, u_model) => {
        const model = _.camelCase(u_model)
        const { value, idx: newIdx, diff, latency } = data
        console.log({ data })

        if (type === 'payload') {
          if (!value) return null;

          payloads[model] = value
          callbacks[model](_.fromPairs(camelizeKeys(value).map(e => [e.id, e])))
          idxs[model] = newIdx + 1
          // Clear any old changes left in the queue
          patchQueues[model] = _.pick(patchQueues[model], _.keys(patchQueues[model]).filter(k => k > newIdx + 1))
          return
        }

        patchQueues[model][newIdx] = diff
        console.log('received', config, { idx: idxs[model], newIdx, latency, diff, patchQueue: patchQueues[model] })

        processQueue(model)

        if (diffSeconds((new Date()), lastCheckAt) >= 3) {
          lastCheckAt = new Date()
          console.log('Interval lost. Pulling from server')
          subscription.send({ type: 'get_payload' })
        }
      })
    })
  })


  // Return so that it can be used in a useEffect to cancel subsciption
  return () => consumer.subscriptions.remove(subscription)
}
