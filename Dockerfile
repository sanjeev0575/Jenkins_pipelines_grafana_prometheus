FROM nginx:alpine

# Copy HTML files to nginx document root
COPY index.html /usr/share/nginx/html/
COPY about.html /usr/share/nginx/html/
COPY services.html /usr/share/nginx/html/
COPY contact.html /usr/share/nginx/html/
COPY styles.css /usr/share/nginx/html/

# Copy custom nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Expose port 80
EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"]