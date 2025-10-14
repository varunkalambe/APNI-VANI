# ===================================================================
# 🎬 APNI VAANI - Video Translation API Dockerfile
# Hugging Face Spaces Compatible - Smart India Hackathon 2024
# ===================================================================

FROM node:18-slim

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# ===================================================================
# SYSTEM DEPENDENCIES
# ===================================================================

# Install system dependencies (FFmpeg, Python, Fonts)
RUN apt-get update && apt-get install -y \
    ffmpeg \
    python3 \
    python3-pip \
    fontconfig \
    fonts-noto-core \
    fonts-noto-mono \
    fonts-noto-ui-core \
    fonts-noto-cjk \
    fonts-noto-color-emoji \
    fonts-noto-extra \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Verify installations
RUN echo "=== Verifying Installations ===" && \
    node --version && \
    npm --version && \
    python3 --version && \
    ffmpeg -version 2>&1 | head -n 1

# ===================================================================
# PYTHON DEPENDENCIES
# ===================================================================

# Use CPU-only PyTorch (smaller size)
RUN pip3 install --no-cache-dir \
    openai-whisper \
    edge-tts \
    numpy \
    torch --index-url https://download.pytorch.org/whl/cpu \
    torchaudio --index-url https://download.pytorch.org/whl/cpu

# Pre-download Whisper model (speeds up first run)
# Add retry logic for robustness
RUN echo "=== Downloading Whisper Model ===" && \
    python3 -c "import whisper; model = whisper.load_model('base'); print('✅ Whisper Model Downloaded Successfully')" || \
    (echo "❌ Failed to download Whisper model - retrying..." && sleep 5 && \
     python3 -c "import whisper; model = whisper.load_model('base'); print('✅ Whisper Model Downloaded Successfully')")

# ===================================================================
# APPLICATION SETUP
# ===================================================================

# Set working directory
WORKDIR /app

# Copy package files first (better caching)
COPY backend/package*.json ./backend/

# Install Node.js dependencies
WORKDIR /app/backend
RUN npm ci --only=production

# Copy entire project
WORKDIR /app
COPY . .

# Create upload directories with proper permissions
RUN mkdir -p \
    uploads/originals \
    uploads/audio \
    uploads/transcription \
    uploads/translations \
    uploads/translated_audio \
    uploads/captions \
    uploads/transcripts \
    uploads/processed \
    uploads/final \
    uploads/temp \
    fonts

# Set permissions (755 is safer than 777)
RUN chmod -R 755 uploads fonts

# ===================================================================
# ENVIRONMENT CONFIGURATION
# ===================================================================

# Environment variables
ENV PORT=7860
ENV NODE_ENV=production
ENV PYTHONUNBUFFERED=1
ENV FFMPEG_PATH=/usr/bin/ffmpeg

# Expose Hugging Face Spaces port
EXPOSE 7860

# ===================================================================
# HEALTH CHECK
# ===================================================================

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD node -e "require('http').get('http://localhost:7860/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# ===================================================================
# START APPLICATION
# ===================================================================

# Start the Node.js server
WORKDIR /app/backend
CMD ["node", "server.js"]
