import jwt, { Secret } from "jsonwebtoken";
import { Request, Response, NextFunction } from "express";

const accessTokenValidate = (req: any, res: Response, next: NextFunction) => {
  try {
    if (!req.headers.authorization) {
      return res.sendStatus(401);
    }

    const token = req.headers.authorization.replace("Bearer ", "");
    jwt.verify(
      token,
      process.env.ACCESS_TOKEN_SECRET as Secret,
      (err: any, decoded: any) => {
        if (err) {
          throw new Error(err.message);
        } else {
          req.user = decoded;
          next();
        }
      }
    );
  } catch (error) {
    return res.sendStatus(401);
  }
};

export default accessTokenValidate;
