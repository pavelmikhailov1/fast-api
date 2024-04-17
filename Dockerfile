# Set Alpine tag version for first and second stage
ARG IMAGE_VERSION_FIRST=3.12.3-alpine3.19
ARG IMAGE_VERSION_SECOND=3.19.1

# First stage
FROM python:${IMAGE_VERSION_FIRST} AS builder

ARG PYTHON_VERSION=3.12

COPY requirements.txt /

# Update base os components and install all deps
RUN apk --no-cache update && \
    apk --no-cache upgrade && \
    apk --no-cache add python3

# Install dependencies to the venv path
RUN python3 -m venv venv
RUN /venv/bin/python3 -m pip install --upgrade pip
RUN pip install --no-cache-dir --target="/venv/lib/python${PYTHON_VERSION}/site-packages" -r /requirements.txt
RUN rm /requirements.txt


# Second unnamed stage
FROM alpine:${IMAGE_VERSION_SECOND}
ARG WORK_DIR_PATH=/usr/ta-worker/
ARG LOG_DIR_PATH=/var/log/ta-worker
ARG PYTHON_VERSION=3.12

# App workdir
WORKDIR ${WORK_DIR_PATH}

# Setup env var
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONPATH=/venv/lib/python3.12/site-packages
ENV PATH=/venv/bin:$PATH

# Сopy only the necessary python files and directories from first stage
COPY --from=builder /usr/local/bin/python3 /usr/local/bin/python3
COPY --from=builder /usr/local/lib/python3.12 /usr/local/lib/python3.12
# COPY --from=builder /usr/local/bin/python{PYTHON_VERSION} /usr/local/bin/python{PYTHON_VERSION}
COPY --from=builder /usr/local/lib/libpython3.12.so.1.0 /usr/local/lib/libpython3.12.so.1.0
COPY --from=builder /usr/local/lib/libpython3.so /usr/local/lib/libpython3.so

# Copy only the dependencies installation from the first stage image
COPY --from=builder /venv /venv

# Update base os components
RUN apk --no-cache update && \
    apk --no-cache upgrade && \
    apk --no-cache add python3-dev postgresql libpq && \
# activate venv
    source /venv/bin/activate && \
    mkdir ${LOG_DIR_PATH} && \
# forward logs to Docker's log collector
    ln -sf /dev/stdout ${LOG_DIR_PATH}/ta-worker.log

# Run app
# !!! needed set log level:
#   - DEBUG
#   - INFO (default)
#   - ERROR
#   - CRITICAL
# !!! needed set pyTMBot mode:
#   - dev
#   - prod (default)
CMD [ "/venv/bin/python3", "src/main.py", "--log-level=INFO", "--mode=prod" ]