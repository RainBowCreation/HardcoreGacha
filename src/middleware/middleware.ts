import { Express } from "express";

import cookieParser from "cookie-parser";
import session from "express-session";

export const Middleware = {
    init(app: Express) {
        app.use(cookieParser());
        app.use(
            session({
                secret: "your_session_secret",
                resave: false,
                saveUninitialized: false,
                cookie: { maxAge: 15 * 60 * 1000 },
            })
         );
    }
}