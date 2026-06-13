FROM node:20

WORKDIR /app

COPY package.json tsconfig.json ./
COPY prisma ./prisma

RUN npm install
RUN npx prisma generate

COPY src ./src

EXPOSE 4000

CMD ["npm", "run", "dev"]

