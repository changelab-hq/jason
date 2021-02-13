export default function createTransportAdapter(jasonConfig: any, handlePayload: any, dispatch: any, onConnect: any): {
    getPayload: (config: any, options: any) => void;
    createSubscription: (config: any) => void;
    removeSubscription: (config: any) => void;
};
