FROM openjdk:11-jre-slim
RUN apt-get update && apt-get install -y \
    curl \
    tesseract-ocr \
    tesseract-ocr-ces \
    tesseract-ocr-lat \
    unzip \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /usr/local/lib
COPY zscanner-entrypoint.sh signing-ca.keystore /usr/local/lib/
COPY opencv-lib /usr/java/packages/lib
EXPOSE 8080
WORKDIR /usr/local/lib
ENTRYPOINT ["/usr/local/lib/zscanner-entrypoint.sh"]
