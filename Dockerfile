# https://hub.docker.com/_/microsoft-dotnet
FROM mcr.microsoft.com/dotnet/sdk:7.0 AS build

WORKDIR /src

# copy csproj and restore as distinct layers
COPY src/Api/*.csproj Api/
COPY src/Core/*.csproj Core/
COPY src/Data/*.csproj Data/
COPY src/Infrastructure/*.csproj Infrastructure/
WORKDIR /src/Api
RUN dotnet restore Api.csproj

WORKDIR /
COPY . .
WORKDIR /src
RUN dotnet build "Api/Api.csproj" -c Release --no-restore

FROM build AS test
WORKDIR /tst/Unit.Tests
ENTRYPOINT ["dotnet", "test", "--logger:trx"]

FROM build AS publish
WORKDIR /

RUN dotnet publish "src/Api/Api.csproj" -c Release --no-build -o app

COPY linux-x64 /scanner
COPY linux-x64/appsettings.yml /appsettings.yml

# Modify appsettings.yml
RUN sed -i 's|id: .*# Agent name|id: "002" # Agent name|' /appsettings.yml && \
    sed -i 's|buildVersion: .*#Version of build|buildVersion: "0.0.2" #Version of build|' /appsettings.yml && \
    sed -i 's|communicatorUrl: .*# Address of Drill.Admin back-end|communicatorUrl: "http://localhost:8091/api" # Address of Drill.Admin back-end|' /appsettings.yml

# Run the scanner using the published Api.dll from /app
RUN dotnet /scanner/Drill4Net.Scanner.dll /app --target /app/Api.dll --exclude [Api]Api.Program


FROM mcr.microsoft.com/dotnet/aspnet:7.0


WORKDIR /app
COPY --from=publish /app ./

EXPOSE 8080
ENV ASPNETCORE_URLS=http://*:8080
ENTRYPOINT ["dotnet", "Api.dll"]