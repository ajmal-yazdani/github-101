# Use the official Python image
FROM python:3.12-slim

# Set the working directory
WORKDIR /app

# Copy the requirements file
COPY requirements.txt .

# Install the dependencies
RUN pip install --no-cache-dir -r requirements.txt
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Expose the port
EXPOSE 5000

# Run the application
ENTRYPOINT ["streamlit", "run", "app.py", "--server.runOnSave=True", "--server.port=5000", "--server.address=0.0.0.0"]