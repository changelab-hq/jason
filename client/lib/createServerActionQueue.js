"use strict";
// A FIFO queue with deduping of actions whose effect will be cancelled by later actions
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const lodash_1 = __importDefault(require("lodash"));
function createServerActionQueue() {
    const queue = [];
    let inFlight = false;
    function addItem(item) {
        // Check if there are any items ahead in the queue that this item would effectively overwrite.
        // In that case we can remove them
        // If this is an upsert && item ID is the same && current item attributes are a superset of the earlier item attributes
        const { type, payload } = item;
        if (type.split('/')[1] !== 'upsert') {
            queue.push(item);
            return;
        }
        lodash_1.default.remove(queue, item => {
            const { type: itemType, payload: itemPayload } = item;
            if (type !== itemType)
                return false;
            if (itemPayload.id !== payload.id)
                return false;
            // Check that all keys of itemPayload are in payload.
            return lodash_1.default.difference(lodash_1.default.keys(itemPayload), lodash_1.default.keys(payload)).length === 0;
        });
        queue.push(item);
    }
    return {
        addItem,
        getItem: () => {
            if (inFlight)
                return false;
            const item = queue.shift();
            if (item) {
                inFlight = true;
                return item;
            }
            return false;
        },
        itemProcessed: () => inFlight = false,
        fullySynced: () => queue.length === 0 && !inFlight,
        getData: () => ({ queue, inFlight })
    };
}
exports.default = createServerActionQueue;
