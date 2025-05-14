# Installation
### clone repository and run
```npm install```

#### this project require npm npx postgresSQL prisma

### create ```.env``` file with
```
DATABASE_URL="postgresql://username:passwordlocalhost:5432/postgres"
DATABASE="postgres"
DATABASE_HOSTNAME="localhost"
DATABASE_PORT="5432"
DATABASE_USERNAME="username"
DATABASE_PASSWORD="password"
ACCESS_TOKEN_SECRET="ACCESS_TOKEN_SECRET"
REFRESH_TOKEN_SECRET="REFRESH_TOKEN_SECRET"
SESSION_SECRET="SESSION_SECRET"
```
### install prima
```npm i prisma```\
```npx prisma init --datasource-provider postgresql```

make sure you have posgres server running.
### migrate sql using
```npx prisma migrate dev --name init```

## Install prima client (optional)
```npm install @prisma/client pg --save```\
to run prisma client on port 5555\
```npx prisma studio```

# Start service
```npm start```\
or use docker