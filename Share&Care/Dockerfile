# Etap bazowy dla runtime
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
WORKDIR /app
EXPOSE 8080
EXPOSE 8081

# Etap build
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
ARG BUILD_CONFIGURATION=Release
WORKDIR /src
COPY ["Share&Care.csproj", "."]
RUN dotnet restore "./Share&Care.csproj"
COPY . .
RUN dotnet build "./Share&Care.csproj" -c $BUILD_CONFIGURATION -o /app/build

# Etap publish
FROM build AS publish
ARG BUILD_CONFIGURATION=Release
RUN dotnet publish "./Share&Care.csproj" -c $BUILD_CONFIGURATION -o /app/publish /p:UseAppHost=false

# Etap finalny
FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .

# 🔹 Dev: jeśli chcesz hot-reload, możesz zamontować wwwroot z compose
# Volumes w compose nadpiszą /app/wwwroot
# COPY .wwwroot /app/wwwroot   <-- nie trzeba, jeśli używasz volumes

ENTRYPOINT ["dotnet", "Share&Care.dll"]
