/// <reference types="react" />
declare const context: import("react").Context<{
    actions: any;
    subscribe: null;
    eager: (entity: any, id: any, relations: any) => void;
}>;
export default context;
