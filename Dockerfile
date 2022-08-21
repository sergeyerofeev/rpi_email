ARG IMAGE_ARCH=linux/arm64/v8

# Базовый образ Dart SDK для платформы arm64
FROM --platform=$IMAGE_ARCH dart:stable AS build

# Устанавливаем рабочий каталог
WORKDIR /app
# Копируем из текущего каталога в рабочий файлы pabspec
COPY pubspec.* ./
# Устанавливаем зависимости
RUN dart pub get

# Скопируем исходный код приложения и AOT скомпилируйте его.
COPY . .
# Убедимся, что пакеты по-прежнему актуальны, если что-то изменилось
RUN dart pub get --offline

# Компилируем
RUN dart compile exe bin/main.dart -o bin/checker_email
# Повышаем права
RUN chmod +x bin/checker_email

# Создаём минимальный образ из AOT-скомпилированного '/checker_email' и установленной OS
# После сборки библиотеки и конфигурационные файлы храняться в '/runtime/'
FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /app/bin/checker_email /app/bin/
COPY --from=build /app/libperiphery_arm64.so /app/

# Запускаем скомпилированное приложение
ENTRYPOINT ["/app/bin/checker_email"]