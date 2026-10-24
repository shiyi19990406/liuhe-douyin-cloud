FROM node:20-alpine
WORKDIR /app
COPY package.json ./
COPY server.js ./
ENV NODE_ENV=production
EXPOSE 8000
RUN mkdir -p /opt/application \
  && printf '#!/bin/sh\nexec node /app/server.js\n' > /opt/application/run.sh \
  && chmod +x /opt/application/run.sh
CMD ["node", "server.js"]
