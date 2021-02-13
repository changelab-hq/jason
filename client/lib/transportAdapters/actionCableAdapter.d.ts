export default function actionCableAdapter(jasonConfig: any, handlePayload: any, dispatch: any, onConnected: any): {
    getPayload: (config: any, options: any) => void;
    createSubscription: (config: any) => void;
    removeSubscription: (config: any) => void;
};
