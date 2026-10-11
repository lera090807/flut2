FROM node:24-alpine
WORKDIR /app
COPY api ./api
USER node
ENV HOST=0.0.0.0 PORT=8080
EXPOSE 8080
CMD ["node", "api/mock-server.js"]
