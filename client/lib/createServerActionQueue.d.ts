export default function createServerActionQueue(): {
    addItem: (action: any) => Promise<any>;
    getItem: () => any;
    itemProcessed: (id: any, data?: any) => void;
    itemFailed: (id: any, error?: any) => void;
    fullySynced: () => boolean;
    getData: () => {
        queue: any[];
        inFlight: boolean;
    };
};
