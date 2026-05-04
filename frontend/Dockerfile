FROM node:20-alpine AS deps

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

FROM node:20-alpine AS build

WORKDIR /app

ARG NEXT_PUBLIC_API_URL=https://backendvibestudying.planoartistico.com/api
ARG NEXT_PUBLIC_ANDROID_APP_URL=
ARG NEXT_PUBLIC_FLUTTER_ANDROID_URL=

ENV NEXT_PUBLIC_API_URL=$NEXT_PUBLIC_API_URL
ENV NEXT_PUBLIC_ANDROID_APP_URL=$NEXT_PUBLIC_ANDROID_APP_URL
ENV NEXT_PUBLIC_FLUTTER_ANDROID_URL=$NEXT_PUBLIC_FLUTTER_ANDROID_URL

COPY --from=deps /app/node_modules ./node_modules

COPY . .
RUN npm run build

FROM node:20-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production
ENV PORT=3000
ENV HOSTNAME=0.0.0.0
ENV NEXT_TELEMETRY_DISABLED=1

COPY --from=build /app/public ./public
COPY --from=build /app/.next/standalone ./
COPY --from=build /app/.next/static ./.next/static

EXPOSE 3000

CMD ["node", "server.js"]
