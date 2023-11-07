
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


FROM build AS publish
WORKDIR /

RUN dotnet publish "src/Api/Api.csproj" -c Release --no-build -o app

COPY scanner/linux-x64 /app/scanner
COPY scanner/linux-x64/appsettings.yml /src/appsettings.yml

FROM mcr.microsoft.com/dotnet/aspnet:7.0

WORKDIR /app
COPY --from=publish /app /src/app

# Go to root and copy the entire content from the /src directory in the build stage
WORKDIR /
COPY --from=build /src /src
COPY --from=publish /src/appsettings.yml /src/appsettings.yml

EXPOSE 8080
ENV ASPNETCORE_URLS=http://*:8080
ENV AGENT_ID=007
ENV GROUP_ID=realworld-app
ENV BUILD_VERSION=0.0.7
ENV COMMUNICATOR_URL=drill-admin:8090

WORKDIR /src

CMD sh -c 'sed -i "s|id: .*# Agent name|id: $AGENT_ID # Agent name|" /src/appsettings.yml && \
 sed -i "s|groupId: .*# Group ID|groupId: $GROUP_ID # Group ID|" /src/appsettings.yml && \
 sed -i "s|buildVersion: .*#Version of build|buildVersion: $BUILD_VERSION #Version of build|" /src/appsettings.yml && \
 sed -i "s|communicatorUrl: .*# Address of Drill.Admin back-end|communicatorUrl: $COMMUNICATOR_URL # Address of Drill.Admin back-end|" /src/appsettings.yml && \
 dotnet app/scanner/Drill4Net.Scanner.dll /src/app --target /src/app/Api.dll && \
 sleep 10 && \
 timeout 10 dotnet app/scanner/Drill4Net.Scanner.dll /src/app --target /src/app/Api.dll && \
 cd /src/app &&\
 dotnet Api.dll'