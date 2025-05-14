import express from "express";
import bodyParser from "body-parser";
import auth from "./routes/auth";

import { Middleware } from "./middleware/middleware"; "./middleware/middleware";
import accessTokenValidate from "./middleware/accessTokenValidate";

const app = express();
app.use(bodyParser.json());
Middleware.init(app);
app.get('/cookies', (req, res) => {
  return res.send(req.cookies);
});
app.get('/sessions', (req, res) => {
  return res.send(req.session)
});
app.use("/api/auth", auth);
app.get("/hello", accessTokenValidate, (req: any, res: any) => {
  return res.status(200).send(`Hello ${req.user.username} Auth by token`);
});
app.listen(3000, () => {
  console.log("Server started on port 3000");
});
