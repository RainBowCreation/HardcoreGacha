import jwt, { Secret } from "jsonwebtoken";
import { Request, Response, NextFunction } from "express";

const refreshTokenValidate = (req: any, res: Response, next: NextFunction) => {
  try {
    var token = '';
    if (!req.body.refreshtoken) {
      token = req.cookies.refreshToken;
    }
    else {
      token = req.body.refreshtoken;
    }

    jwt.verify(
      token,
      process.env.REFRESH_TOKEN_SECRET as Secret,
      (err: any, decoded: any) => {
        if (err) {
          throw new Error(err.message);
        } else {
          req.user = decoded;
          delete req.user.exp;
          delete req.user.iat;
          next();
        }
      }
    );
  } catch (error) {
    return res.sendStatus(403);
  }
};

export default refreshTokenValidate;
