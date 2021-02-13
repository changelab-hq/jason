export default function createPayloadHandler({ dispatch, serverActionQueue, transportAdapter, config }: {
    dispatch: any;
    serverActionQueue: any;
    transportAdapter: any;
    config: any;
}): {
    handlePayload: (data: any) => void;
    tearDown: () => void;
};
