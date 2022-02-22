#Depending on the operating system of the host machines(s) that will build or run the containers, the image specified in the FROM statement may need to be changed.
#For more information, please see https://aka.ms/containercompat
ARG SOURCE
FROM mcr.microsoft.com/dotnet/framework/sdk:4.8-windowsservercore-ltsc2019 as builder
WORKDIR /app_src
COPY ${SOURCE:-.} .
RUN nuget restore
RUN msbuild -p:Configuration=Release -p:DeployOnBuild=true -p:PublishProfile="FolderProfile.pubxml" -r:false -verbosity:minimal WinContainersPageFile.sln

FROM mcr.microsoft.com/dotnet/framework/aspnet:4.8-windowsservercore-ltsc2019
WORKDIR /inetpub/wwwroot
COPY --from=builder /app_src/WinContainersPageFiles.Web/bin/app.publish/ ./
