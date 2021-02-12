export default function createPayloadHandler({ dispatch, serverActionQueue, subscription, config }: {
    dispatch: any;
    serverActionQueue: any;
    subscription: any;
    config: any;
}): {
    handlePayload: (data: any) => void;
    tearDown: () => void;
};
