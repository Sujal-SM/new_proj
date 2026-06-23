# ─────────────────────────────────────────
# Stage 1: deps — install ALL deps for audit
# ─────────────────────────────────────────
FROM node:20-alpine AS deps

WORKDIR /app

COPY package*.json ./
RUN npm ci

# ─────────────────────────────────────────
# Stage 2: prod-deps — production only
# ─────────────────────────────────────────
FROM node:20-alpine AS prod-deps

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

# ─────────────────────────────────────────
# Stage 3: final — lean production image
# ─────────────────────────────────────────
FROM node:20-alpine AS final

# Add non-root user for security
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodeuser -u 1001 -G nodejs

WORKDIR /app

# Copy production node_modules from prod-deps stage
COPY --from=prod-deps --chown=nodeuser:nodejs /app/node_modules ./node_modules

# Copy application source
COPY --chown=nodeuser:nodejs server.js ./
COPY --chown=nodeuser:nodejs src/ ./src/
COPY --chown=nodeuser:nodejs scripts/ ./scripts/
COPY --chown=nodeuser:nodejs package.json ./

# Switch to non-root user
USER nodeuser

# Expose backend port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1

CMD ["node", "server.js"]
