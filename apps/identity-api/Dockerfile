# ---------- build stage ----------
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Sadece bu servisi kopyalıyoruz; build context repo kökü olacak
COPY apps/identity-api/ ./apps/identity-api/

# Restore + publish
RUN dotnet restore apps/identity-api/Identity.Api.csproj
RUN dotnet publish apps/identity-api/Identity.Api.csproj -c Release -o /out /p:UseAppHost=false

# ---------- runtime stage ----------
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app
ENV ASPNETCORE_URLS=http://+:8080

COPY --from=build /out ./

EXPOSE 8080
ENTRYPOINT ["dotnet", "Identity.Api.dll"]
