# ==========================================
# STAGE 1: Build & Dependency Resolution
# ==========================================
FROM node:20-alpine AS builder

# Set the working directory
WORKDIR /app

# Copy only the package files first to leverage Docker Layer Caching
# This ensures 'npm install' only runs when dependencies change
COPY package*.json ./

# Install production dependencies only (Security & Size Optimization)
RUN npm ci --omit=dev && npm cache clean --force

# ==========================================
# STAGE 2: Final Runtime Image
# ==========================================
FROM node:20-alpine

# Metadata for traceability
LABEL project="mini-write"

# Set Production Environment
ENV NODE_ENV=production \
    NODE_OPTIONS="--max-old-space-size=256"

WORKDIR /app

RUN apk add --no-cache curl

# Copy node_modules from the builder stage
COPY --from=builder /app/node_modules ./node_modules

# Copy the rest of the application source code
COPY . .

# SECURITY: Run as a non-root user (node is pre-defined in alpine image)
# This prevents privilege escalation attacks
RUN chown -R node:node /app

USER node

# Document the port the container listens on
EXPOSE 3000

# Use EXEC form for CMD to ensure SIGTERM signals are handled correctly (PID 1)
# This allows for Graceful Shutdown of the application
CMD ["node", "src/index.js"]
