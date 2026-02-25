# 前端代码构建环境
FROM node:20-alpine AS frontend

WORKDIR /app

COPY ./frontend/package.json ./frontend/package-lock.json ./

RUN npm install -g cnpm --registry=https://registry.npmmirror.com \
    && cnpm install \
    && npm cache clean --force

COPY ./frontend/ ./

RUN npm run build

# 最终运行环境（ARM32 - 直接运行 Python）
FROM python:3.11-slim-bullseye

WORKDIR /app

# 复制前端构建产物
COPY --from=frontend /app/dist ./frontend

# 安装运行时依赖
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        nginx \
        ffmpeg \
        gcc \
        build-essential \
        libffi-dev \
    && rm -rf /var/lib/apt/lists/*

# 复制后端代码
COPY ./backend/ ./backend/

# 安装 Python 依赖
WORKDIR /app/backend
RUN pip install --no-cache-dir -i https://pypi.tuna.tsinghua.edu.cn/simple --prefer-binary -r requirements.txt

# 复制环境配置
COPY ./.env ./

# 注入版本号
ARG SYSTEM_VERSION
ENV SYSTEM_VERSION=${SYSTEM_VERSION}
RUN echo "SYSTEM_VERSION=${SYSTEM_VERSION}" >> ./.env

# 复制 nginx 配置
COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 9527

# 使用 Python 直接运行
CMD service nginx start && python main.py
