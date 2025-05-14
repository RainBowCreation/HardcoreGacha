"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const jsonwebtoken_1 = __importDefault(require("jsonwebtoken"));
const accessTokenValidate = (req, res, next) => {
    try {
        var token = '';
        if (!req.headers.authorization) {
            token = req.session.accessToken;
        }
        else {
            token = req.headers.authorization.replace("Bearer ", "");
        }
        jsonwebtoken_1.default.verify(token, process.env.ACCESS_TOKEN_SECRET, (err, decoded) => {
            if (err) {
                throw new Error(err.message);
            }
            else {
                req.user = decoded;
                next();
            }
        });
    }
    catch (error) {
        return res.sendStatus(401);
    }
};
exports.default = accessTokenValidate;
