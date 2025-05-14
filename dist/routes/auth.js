"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const auth_1 = require("../controller/auth");
const express_1 = __importDefault(require("express"));
const accessTokenValidate_1 = __importDefault(require("../middleware/accessTokenValidate"));
const refreshTokenValidate_1 = __importDefault(require("../middleware/refreshTokenValidate"));
const router = express_1.default.Router();
router.post("/register", auth_1.Register);
router.post("/login", auth_1.Login);
router.post("/refresh", refreshTokenValidate_1.default, auth_1.refreshToken);
router.post("/logout", accessTokenValidate_1.default, auth_1.Logout);
exports.default = router;
