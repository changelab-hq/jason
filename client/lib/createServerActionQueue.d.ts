export default function createServerActionQueue(): {
    addItem: (item: any) => void;
    getItem: () => any;
    itemProcessed: () => boolean;
    fullySynced: () => boolean;
    getData: () => {
        queue: any[];
        inFlight: boolean;
    };
};
