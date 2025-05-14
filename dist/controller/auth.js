"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.refreshToken = exports.Logout = exports.Login = exports.Register = void 0;
const db_1 = __importDefault(require("../utils/db"));
const bcrypt_1 = __importDefault(require("bcrypt"));
const generateToken_1 = require("../utils/generateToken");
const jsonwebtoken_1 = __importDefault(require("jsonwebtoken"));
const Register = async (req, res, next) => {
    try {
        const { username, password } = req.body;
        if (!username || !password) {
            return res
                .status(400)
                .json({ message: "Username and password are required" });
        }
        const existingUser = await db_1.default.user.findUnique({
            where: {
                username: username,
            },
        });
        if (existingUser) {
            return res.status(409).send("User already exists. Please login");
        }
        else {
            const hashedPassword = await bcrypt_1.default.hash(password, 10);
            await db_1.default.user.create({
                data: {
                    username: username,
                    password: hashedPassword,
                },
            });
            return res.status(201).json({ message: "register complete" });
        }
    }
    catch (error) {
        console.log(error);
        return res.status(500).send("Internal server error");
    }
};
exports.Register = Register;
const Login = async (req, res, next) => {
    try {
        const { username, password } = req.body;
        if (!username || !password) {
            return res
                .status(400)
                .json({ message: "Username and password are required" });
        }
        const user = await db_1.default.user.findUnique({
            where: {
                username: username,
            },
        });
        if (user && (await bcrypt_1.default.compare(password, user.password))) {
            const tokens = (0, generateToken_1.generateTokens)(user);
            await db_1.default.user.update({
                where: {
                    id: user.id,
                },
                data: {
                    refreshtoken: tokens.refreshToken,
                },
            });
            // Store access token in session
            req.session.accessToken = tokens.accessToken;
            // Store refresh token in HttpOnly cookie
            res.cookie("refreshToken", tokens.refreshToken, {
                httpOnly: true,
                secure: true,
                sameSite: "strict",
                maxAge: 30 * 24 * 60 * 60 * 1000, // 30 days
            });
            return res.status(200).json({
                accesstoken: tokens.accessToken,
                refreshtoken: tokens.refreshToken,
            });
        }
        return res.status(400).send("Invalid credentials");
    }
    catch (error) {
        console.log(error);
        return res.status(500).send("Internal server error");
    }
};
exports.Login = Login;
const Logout = async (req, res, next) => {
    try {
        // do log out
        return res.status(400).send("Invalid credentials");
    }
    catch (error) {
        console.log(error);
        return res.status(500).send("Internal server error");
    }
};
exports.Logout = Logout;
const refreshToken = async (req, res) => {
    try {
        console.log("refresh token work");
        const username = req.user.username;
        let newToken;
        const oldUser = await db_1.default.user.findUnique({
            where: {
                username: req.user.username,
            },
        });
        const oldRefreshToken = oldUser?.refreshtoken;
        var refreshTokenFromReq = '';
        if (!req.body.refreshtoken) {
            refreshTokenFromReq = req.cookies.refreshToken;
        }
        else {
            refreshTokenFromReq = req.body.refreshtoken;
        }
        // Check if refresh token in the request body matches the one in the database
        console.log("Old Refresh Token = " + oldRefreshToken);
        console.log("refresh token from request = " + refreshTokenFromReq);
        if (oldRefreshToken?.toString() !== refreshTokenFromReq.toString()) {
            console.log("not same refreshtoken");
            return res.sendStatus(401);
        }
        // Verify the validity of the refresh token
        const isValidRefreshToken = jsonwebtoken_1.default.verify(String(oldRefreshToken), process.env.REFRESH_TOKEN_SECRET);
        if (!isValidRefreshToken) {
            return res.sendStatus(401);
        }
        if (oldUser) {
            const token = (0, generateToken_1.generateTokens)(oldUser);
            newToken = token;
        }
        console.log("New Refresh Token = " + newToken?.refreshToken);
        await db_1.default.user.update({
            where: {
                id: oldUser?.id,
            },
            data: {
                refreshtoken: newToken?.refreshToken,
            },
        });
        req.session.accessToken = newToken?.accessToken;
        // Store refresh token in HttpOnly cookie
        res.cookie("refreshToken", newToken?.refreshToken, {
            httpOnly: true,
            secure: true,
            sameSite: "strict",
            maxAge: 30 * 24 * 60 * 60 * 1000, // 30 days
        });
        const user = {
            username: oldUser?.username,
            accesstoken: newToken?.accessToken,
            refreshtoken: newToken?.refreshToken,
        };
        return res.status(201).json(user);
    }
    catch (err) {
        console.log(err);
        return res.status(500).send("Internal server error");
    }
};
exports.refreshToken = refreshToken;
