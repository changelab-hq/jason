/// <reference types="react" />
import _useAct from './useAct';
import _useSub from './useSub';
import _useEager from './useEager';
export declare const JasonProvider: ({ reducers, middleware, enhancers, extraActions, children }: {
    reducers?: any;
    middleware?: any;
    enhancers?: any;
    extraActions?: any;
    children?: import("react").FC<{}> | undefined;
}) => JSX.Element;
export declare const useAct: typeof _useAct;
export declare const useSub: typeof _useSub;
export declare const useEager: typeof _useEager;
