"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const jsonwebtoken_1 = __importDefault(require("jsonwebtoken"));
const refreshTokenValidate = (req, res, next) => {
    try {
        if (!req.body.refreshtoken)
            return res.sendStatus(401);
        const token = req.body.refreshtoken;
        jsonwebtoken_1.default.verify(token, process.env.REFRESH_TOKEN_SECRET, (err, decoded) => {
            if (err) {
                throw new Error(err.message);
            }
            else {
                req.user = decoded;
                delete req.user.exp;
                delete req.user.iat;
                next();
            }
        });
    }
    catch (error) {
        return res.sendStatus(403);
    }
};
exports.default = refreshTokenValidate;
