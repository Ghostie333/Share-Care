# =========================
# Etap bazowy dla runtime
# =========================
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base

WORKDIR /app

EXPOSE 8080
EXPOSE 8081

# =========================
# Etap build
# =========================
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build

ARG BUILD_CONFIGURATION=Release

WORKDIR /src

# -------------------------
# Install Flutter
# -------------------------
RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*

ENV FLUTTER_HOME=/opt/flutter
ENV PATH="${FLUTTER_HOME}/bin:${FLUTTER_HOME}/bin/cache/dart-sdk/bin:${PATH}"

# Install Flutter
RUN git clone https://github.com/flutter/flutter.git ${FLUTTER_HOME}

# Use stable channel
RUN flutter channel stable && flutter upgrade

# Disable analytics
RUN flutter config --no-analytics

# Precache Flutter web dependencies
RUN flutter precache --web

# Verify Flutter installation
RUN flutter doctor

# -------------------------
# Copy .NET project
# -------------------------
COPY ["Share&Care.csproj", "."]

RUN dotnet restore "./Share&Care.csproj"

COPY . .

# =========================
# Build Flutter frontend
# =========================
WORKDIR /src/wwwroot/frontend

# Clean previous Flutter builds
RUN flutter clean

# Install Flutter dependencies
RUN flutter pub get

# Build Flutter web app
RUN flutter build web --release

# Save Flutter build to temp folder
RUN mkdir -p /src/flutter-build && \
    cp -r build/web/* /src/flutter-build/

# =========================
# Build .NET app
# =========================
WORKDIR /src

RUN dotnet build "./Share&Care.csproj" \
    -c ${BUILD_CONFIGURATION} \
    -o /app/build

# =========================
# Publish
# =========================
FROM build AS publish

ARG BUILD_CONFIGURATION=Release

RUN dotnet publish "./Share&Care.csproj" \
    -c ${BUILD_CONFIGURATION} \
    -o /app/publish \
    /p:UseAppHost=false

# Copy Flutter build into ASP.NET wwwroot
RUN mkdir -p /app/publish/wwwroot && \
    cp -r /src/flutter-build/* /app/publish/wwwroot/

# =========================
# Final image
# =========================
FROM base AS final

WORKDIR /app

COPY --from=publish /app/publish .

ENTRYPOINT ["dotnet", "Share&Care.dll"]