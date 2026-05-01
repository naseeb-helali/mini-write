# ==========================================
# STAGE 1: Build & Dependency Resolution
# ==========================================
FROM node:20-alpine AS builder

# 1. Install build dependencies (needed only for compiling 'sharp')
RUN apk add --no-cache \
    libc6-compat \
    python3 \
    make \
    g++ \
    vips-dev

WORKDIR /usr/src/app

# 2. Copy dependency files first (Optimizing Layer Caching)
COPY package*.json ./

# 3. Install ALL dependencies including those needed for build
RUN npm ci --omit=dev && npm cache clean --force

# 4. Copy the rest of the application
COPY . .

# ==========================================
# STAGE 2: Final Runtime Image
# ==========================================
FROM node:20-alpine AS runner

# 5. Install runtime shared libraries for Sharp
RUN apk add --no-cache vips

WORKDIR /usr/src/app

# 8. Environment variables defaults
ENV NODE_ENV=production \
    NODE_OPTIONS="--max-old-space-size=512"

# 6. Copy only the production node_modules and built code from the builder
COPY --from=builder /usr/src/app/node_modules ./node_modules
COPY --from=builder /usr/src/app/src ./src
COPY --from=builder /usr/src/app/package.json ./package.json

RUN chown -R node:node /usr/src/app

# 7. Security: Run as a non-privileged user
USER node

CMD ["node", "src/index.js"]
