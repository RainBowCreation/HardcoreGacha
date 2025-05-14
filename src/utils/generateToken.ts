import jwt from "jsonwebtoken";

type tokenInfomation = {
  username: string;
};

export function generateTokens(user: tokenInfomation) {
  const { username } = user;
  const accessToken = jwt.sign(
    { username: username }, // payload
    process.env.ACCESS_TOKEN_SECRET as string, // กำหนด secret
    { expiresIn: "3m", algorithm: "HS256" } // อายุ เเละ algorithm ในการสร้าง jwt
  );
  const refreshToken = jwt.sign(
    { username: username }, // payload
    process.env.REFRESH_TOKEN_SECRET as string, // กำหนด secret
    { expiresIn: "1d", algorithm: "HS256" } // อายุ เเละ algorithm ในการสร้าง jwt
  );
  return { accessToken, refreshToken };
}
