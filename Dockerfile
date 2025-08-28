# ~~~~~~~~~~~~~~ STAGE 1: Base ~~~~~~~~~~~~~~
# Define a common base image with Node.js and essential tools.
# Using a specific version tag is better than `latest`.
# Alpine is used for its small size.
FROM node:20-alpine AS base
WORKDIR /usr/src/app

# Install `dumb-init` for proper signal handling and to prevent zombie processes.
RUN apk add --no-cache dumb-init


# ~~~~~~~~~~~~~~ STAGE 2: Dependencies ~~~~~~~~~~~~~~

FROM base AS deps
COPY package.json package-lock.json* ./
RUN npm ci --omit=dev


# ~~~~~~~~~~~~~~ STAGE 3: Builder ~~~~~~~~~~~~~~
# This stage builds the application source code.
# It installs all dependencies (including dev) to run the build script.
FROM base AS builder
COPY package.json package-lock.json* ./
RUN npm ci

# Copy the rest of your application source code
COPY . .

# Run the build script defined in your package.json
# (e.g., `tsc`, `next build`, `vite build`)
RUN npm run build


# ~~~~~~~~~~~~~~ STAGE 4: Final Production Image ~~~~~~~~~~~~~~
# This is the final, lean image that will be deployed.
# We start from the clean base image again.
FROM base AS runner

# Set the environment to production
ENV NODE_ENV=production
# Set a default port, can be overridden at runtime.

# Create a non-root user and group for security.
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

# Copy pre-installed production dependencies from the `deps` stage.
COPY --from=deps /usr/src/app/node_modules ./node_modules

# Copy the built application code from the `builder` stage.
# The folder name depends on your framework (e.g., .next, dist, build).
COPY --from=builder /usr/src/app/.next ./.next
COPY --from=builder /usr/src/app/public ./public
COPY --from=builder /usr/src/app/package.json ./package.json

# Copy dumb-init from the base stage.
COPY --from=base /usr/bin/dumb-init /usr/local/bin/dumb-init

# Change ownership of application files to the non-root user.
RUN chown -R nextjs:nodejs .

# Switch to the non-root user.
USER nextjs

# Expose the port the app runs on.
EXPOSE 3000

# Set the entrypoint to use dumb-init, which runs your command as PID 1.
ENTRYPOINT ["/usr/local/bin/dumb-init", "--"]

# The command to start the application.
# `npm start` should be defined in your package.json's scripts section.
CMD ["npm", "start"]
