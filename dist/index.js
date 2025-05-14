"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const body_parser_1 = __importDefault(require("body-parser"));
const auth_1 = __importDefault(require("./routes/auth"));
const accessTokenValidate_1 = __importDefault(require("./middleware/accessTokenValidate"));
const app = (0, express_1.default)();
app.use(body_parser_1.default.json());
app.use("/api/auth", auth_1.default);
app.get("/hello", accessTokenValidate_1.default, (req, res) => {
    return res.status(200).send(`Hello ${req.user.username} Auth by token`);
});
app.listen(3000, () => {
    console.log("Server started on port 3000");
});
