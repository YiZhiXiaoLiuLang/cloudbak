
# 前端代码构建环境
FROM node:20-alpine AS frontend

WORKDIR /app

# 先复制 package.json 并执行安装，利用 Docker 缓存
COPY ./frontend/package.json ./frontend/package-lock.json ./

# 安装 cnpm 并安装依赖
RUN npm install -g cnpm --registry=https://registry.npmmirror.com \
    && cnpm install \
    && npm cache clean --force

# 复制前端源代码
COPY ./frontend/ ./

# 构建前端
RUN npm run build

# Python 代码编译环境
FROM python:3.11-slim-bullseye AS builder
WORKDIR /app/backend

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    gcc \
    python3-dev \
    libffi-dev \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

COPY ./backend/requirements.txt ./

RUN python -m pip install --upgrade pip setuptools wheel \
    && pip install --no-cache-dir --prefer-binary -r requirements.txt

# 复制剩余代码
COPY ./backend/ ./

# 安装 pyinstaller 并编译 Python 可执行文件
RUN pip install --no-cache-dir pyinstaller \
    && pyinstaller --onefile main.py \
    && pyinstaller --onefile user_password_reset.py \
    && pyinstaller --onefile decrypt_db.py

# 最终运行环境
FROM python:3.11-slim-bullseye AS backend

WORKDIR /app

# 复制前端构建产物
COPY --from=frontend /app/dist ./frontend

# 安装运行时依赖
RUN apt-get update \
    && apt-get install -y --no-install-recommends nginx ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# 复制编译好的可执行文件
COPY --from=builder /app/backend/dist/main ./backend/main
COPY --from=builder /app/backend/dist/user_password_reset ./backend/user_password_reset
COPY --from=builder /app/backend/dist/decrypt_db ./backend/decrypt_db

# 复制环境配置文件
COPY ./.env ./backend/

# 注入版本号
ARG SYSTEM_VERSION
ENV SYSTEM_VERSION=${SYSTEM_VERSION}
RUN echo "SYSTEM_VERSION=${SYSTEM_VERSION}" >> ./backend/.env

# 复制 nginx 配置
COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 9527

WORKDIR /app/backend

CMD service nginx start && ./main
