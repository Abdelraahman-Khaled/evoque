# Stage 1: Install dependencies
FROM node:20-alpine AS deps
WORKDIR /app
COPY package*.json ./
COPY prisma ./prisma
RUN npm install

# Stage 2: Build the application
FROM node:20-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
# We need to generate the Prisma client during build
RUN npx prisma generate
RUN npm run build

# Stage 3: Production runner
FROM node:20-alpine AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

# Install openssl and libc6-compat for Prisma
RUN apk add --no-cache openssl libc6-compat

# Create a data directory for the SQLite database
RUN mkdir -p /app/prisma/data

COPY --from=builder /app/public ./public
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/prisma ./prisma

# Install prisma CLI globally or just use local version if available
# Since we are in standalone, we might need a minimal prisma CLI
RUN npm install -g prisma@5.22.0

# Expose the port
ENV PORT=9199
EXPOSE 9199

# Start the application
CMD ["sh", "-c", "prisma db push && node server.js"]
