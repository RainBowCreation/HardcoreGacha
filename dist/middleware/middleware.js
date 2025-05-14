"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.Middleware = void 0;
const cookie_parser_1 = __importDefault(require("cookie-parser"));
const express_session_1 = __importDefault(require("express-session"));
exports.Middleware = {
    init(app) {
        app.use((0, cookie_parser_1.default)());
        app.use((0, express_session_1.default)({
            secret: "your_session_secret",
            resave: false,
            saveUninitialized: false,
            cookie: { maxAge: 15 * 60 * 1000 },
        }));
    }
};
