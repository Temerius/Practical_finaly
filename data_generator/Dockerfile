FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy generator script
COPY generate_data.py .

# Set default environment variables
ENV DATA_FILE_SIZE_GB=16
ENV NUM_LARGE_FILES=2
ENV DATA_OUTPUT_DIR=/data
ENV CORRUPTION_RATE=0.001
ENV MISSING_DATA_RATE=0.05
ENV DUPLICATE_RATE=0.02
ENV OUTLIER_RATE=0.01

# Make script executable
RUN chmod +x generate_data.py

# Run generator
CMD ["python", "generate_data.py"]

