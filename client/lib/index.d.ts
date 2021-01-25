/// <reference types="react" />
import _useAct from './useAct';
import _useSub from './useSub';
export declare const JasonProvider: ({ reducers, middleware, extraActions, children }: {
    reducers?: any;
    middleware?: any;
    extraActions?: any;
    children?: import("react").FC<{}> | undefined;
}) => JSX.Element;
export declare const useAct: typeof _useAct;
export declare const useSub: typeof _useSub;
