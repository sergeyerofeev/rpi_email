import 'dart:io' show Platform;
import 'package:postgres/postgres.dart';

class DBRepository {
  static DBRepository? _db;

  DBRepository._();
  factory DBRepository() => _db ??= DBRepository._();

  PostgreSQLConnection? _connection;
  // Создадим геттер
  Future<PostgreSQLConnection> get connection async => _connection ??= await initDB();

  Future<PostgreSQLConnection> initDB() async {
    final host = Platform.environment['DB_HOST'] ?? '';
    final port = int.parse(Platform.environment['DB_PORT'] ?? '');
    final databaseName = Platform.environment['DB_NAME'] ?? '';
    final dbUserName = Platform.environment['DB_USERNAME'] ?? '';
    final dbPassword = Platform.environment['DB_PASSWORD'] ?? '';
    final timeZone = Platform.environment['DB_TIMEZONE'] ?? '';

    // Создаём соединение с БД PostgreSQL
    var connection = PostgreSQLConnection(
      host,
      port,
      databaseName,
      username: dbUserName,
      password: dbPassword,
      timeZone: timeZone,
    );

    await connection.open();
    return connection;
  }

  // Вставляем данные в БД сначала проверив на дублирование
  Future<bool> checkAndSaveEmail(String? senderEmail, String? nameEmail, DateTime? deliveryDate) async {
    final db = await connection;
    // Флаг, успешно ли прошло сохранение данных
    bool flag = false;
    // Начинаем транзакцию, сначала проверка, затем сохранение email
    await db.transaction((ctx) async {
      // Проверяем есть ли сохранённое email с таким же senderEmail и deliveryDate
      var result = await ctx.query(
        '''SELECT id 
          FROM email_data
          WHERE email = @email AND delivery_date = @delivery_date''',
        substitutionValues: {
          'email': senderEmail,
          'delivery_date': deliveryDate,
        },
      );

      if (result.isEmpty) {
        PostgreSQLResult id = await ctx.query(
          '''INSERT INTO 
            email_data (email, name_email, delivery_date)
          VALUES(@email, @name_email, @delivery_date)
          RETURNING id''',
          substitutionValues: {
            'email': senderEmail,
            'name_email': nameEmail,
            'delivery_date': deliveryDate,
          },
        );
        if (id.first[0] != -1) {
          flag = true;
        }
      }
      if (!flag) {
        // Если email уже присутствует в БД или произошла ошибка при записи, отменяем транзакцию
        ctx.cancelTransaction();
        return flag;
      }
    });
    // Транзакция прошла успешно, возвращаем true
    return flag;
  }
}
