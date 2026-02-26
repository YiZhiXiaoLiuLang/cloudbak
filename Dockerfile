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
FROM python:3.9.19-slim-bullseye

WORKDIR /app

# 复制前端构建产物
COPY --from=frontend /app/dist ./frontend

# 安装运行时依赖和编译工具
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        nginx \
        ffmpeg \
        gcc \
        g++ \
        build-essential \
        libffi-dev \
        git \
        cmake \
        make \
    && rm -rf /var/lib/apt/lists/*

# 复制后端代码
COPY ./backend/ ./backend/

WORKDIR /app/backend

# 从源码编译安装 pilk（避免 ARM32 预编译二进制问题）
RUN pip install --no-cache-dir --no-binary pilk pilk || echo "pilk installation failed, will try from git"

# 如果上面失败，从 GitHub 源码安装
RUN if ! python -c "import pilk" 2>/dev/null; then \
        cd /tmp && \
        git clone https://github.com/foyoux/pilk.git && \
        cd pilk && \
        pip install --no-cache-dir . || echo "WARNING: pilk installation from source also failed"; \
    fi

# 移除 requirements.txt 中的 pilk（已单独安装）
RUN grep -v "^pilk" requirements.txt > requirements_temp.txt || cp requirements.txt requirements_temp.txt

# 安装其他 Python 依赖
RUN pip install --no-cache-dir -i https://pypi.tuna.tsinghua.edu.cn/simple --prefer-binary -r requirements_temp.txt

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
