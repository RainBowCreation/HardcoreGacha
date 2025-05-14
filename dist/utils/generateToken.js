"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.generateTokens = void 0;
const jsonwebtoken_1 = __importDefault(require("jsonwebtoken"));
function generateTokens(user) {
    const { username } = user;
    const accessToken = jsonwebtoken_1.default.sign({ username: username }, // payload
    process.env.ACCESS_TOKEN_SECRET, // กำหนด secret
    { expiresIn: "3m", algorithm: "HS256" } // อายุ เเละ algorithm ในการสร้าง jwt
    );
    const refreshToken = jsonwebtoken_1.default.sign({ username: username }, // payload
    process.env.REFRESH_TOKEN_SECRET, // กำหนด secret
    { expiresIn: "1d", algorithm: "HS256" } // อายุ เเละ algorithm ในการสร้าง jwt
    );
    return { accessToken, refreshToken };
}
exports.generateTokens = generateTokens;
