import { Register, Login, refreshToken } from "../controller/auth";
import express from "express";
import accessTokenValidate from "../middleware/accessTokenValidate";
import jwtRefreshTokenValidate from "../middleware/refreshTokenValidate";

const router = express.Router();

router.post("/register", Register);
router.post("/login", Login);
router.post("/refresh", jwtRefreshTokenValidate, refreshToken);

export default router;
