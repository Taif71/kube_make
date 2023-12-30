# Dockerfile

# Use the official Nginx image as the base image
FROM nginx:latest

# Copy the custom Nginx configuration file to the container
COPY nginx.conf /etc/nginx/nginx.conf

# Copy the HTML file to the default Nginx HTML directory
COPY index.html /usr/share/nginx/html/

# Expose port 80
EXPOSE 80

# Start Nginx in the foreground
CMD ["nginx", "-g", "daemon off;"]