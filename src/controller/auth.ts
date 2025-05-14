import { Request, Response, NextFunction } from "express";
import db from "../utils/db";
import bcrypt from "bcrypt";
import { generateTokens } from "../utils/generateToken";
import jwt, { Secret } from "jsonwebtoken";
export const Register = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const { username, password } = req.body;
    if (!username || !password) {
      return res
        .status(400)
        .json({ message: "Username and password are required" });
    }

    const existingUser = await db.user.findUnique({
      where: {
        username: username,
      },
    });
    if (existingUser) {
      return res.status(409).send("User already exists. Please login");
    } else {
      const hashedPassword = await bcrypt.hash(password, 10);

      await db.user.create({
        data: {
          username: username,
          password: hashedPassword,
        },
      });

      return res.status(201).json({ message: "register complete" });
    }
  } catch (error) {
    console.log(error);
    return res.status(500).send("Internal server error");
  }
};

export const Login = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const { username, password } = req.body;
    if (!username || !password) {
      return res
        .status(400)
        .json({ message: "Username and password are required" });
    }
    const user = await db.user.findUnique({
      where: {
        username: username,
      },
    });
    if (user && (await bcrypt.compare(password, user.password))) {
      const tokens = generateTokens(user);

      await db.user.update({
        where: {
          id: user.id,
        },
        data: {
          refreshtoken: tokens.refreshToken,
        },
      });
      return res.status(200).json({
        accesstoken: tokens.accessToken,
        refreshtoken: tokens.refreshToken,
      });
    }
    return res.status(400).send("Invalid credentials");
  } catch (error) {
    console.log(error);
    return res.status(500).send("Internal server error");
  }
};

export const refreshToken = async (req: any, res: Response) => {
  try {
    console.log("refresh token work");
    const username = req.user.username;
    let newToken;
    const oldUser = await db.user.findUnique({
      where: {
        username: req.user.username,
      },
    });
    const oldRefreshToken = oldUser?.refreshtoken;
    const refreshTokenFromBody = req.body.refreshtoken;

    // Check if refresh token in the request body matches the one in the database
    console.log("Old Refresh Token = " + oldRefreshToken);
    console.log("refresh token from request = " + refreshTokenFromBody);
    if (oldRefreshToken?.toString() !== refreshTokenFromBody.toString()) {
      console.log("not same refreshtoken");
      return res.sendStatus(401);
    }
    // Verify the validity of the refresh token
    const isValidRefreshToken = jwt.verify(
      String(oldRefreshToken),
      process.env.REFRESH_TOKEN_SECRET as Secret
    ) as jwt.JwtPayload;

    if (!isValidRefreshToken) {
      return res.sendStatus(401);
    }

    if (oldUser) {
      const token = generateTokens(oldUser);
      newToken = token;
    }

    console.log("New Refresh Token = " + newToken?.refreshToken);

    await db.user.update({
      where: {
        id: oldUser?.id,
      },
      data: {
        refreshtoken: newToken?.refreshToken,
      },
    });

    const user = {
      username: oldUser?.username,
      accesstoken: newToken?.accessToken,
      refreshtoken: newToken?.refreshToken,
    };

    return res.status(201).json(user);
  } catch (err) {
    console.log(err);
    return res.status(500).send("Internal server error");
  }
};
