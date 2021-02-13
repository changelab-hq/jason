export default function pusherAdapter(jasonConfig: any, handlePayload: any, dispatch: any): {
    getPayload: (config: any, options: any) => void;
    createSubscription: (config: any) => void;
    removeSubscription: (config: any) => void;
};
