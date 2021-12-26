FROM node:9

# Create app directory
WORKDIR /app

# Install app dependencies
COPY node-hostname/package*.json ./

RUN npm install

# Copying rest of the application to app directory
COPY node-hostname /app

# Expose the port and start the application
Expose 3000

CMD ["npm","start"]