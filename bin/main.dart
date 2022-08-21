import 'dart:io' show Platform;
import 'dart:isolate';

import 'package:dart_periphery/dart_periphery.dart';
import 'package:enough_mail/enough_mail.dart';

import 'repository/db_repository.dart';

final envVar = Platform.environment;

final emailUserName = envVar['EMAIL_USERNAME'] ?? '';
final emailPassword = envVar['EMAIL_PASSWORD'] ?? '';

void main() async {
  await mailExample();
}

/// High level mail API example
Future<void> mailExample() async {
  final email = '$emailUserName@mail.ru';

  // Регулярное выражение для извлечения наименования отправителя почтового сообщения
  final exp = RegExp(r'"([_\-A-Za-z А-Яа-яЁё]+)"');

  // Данные о поступившем письме
  String? senderEmail;
  String? nameEmail;
  DateTime? deliveryDate;

  //----------------------Инициализация БД----------------------
  final dbRepository = DBRepository();
  bool resultTransaction = false;

  //---------------------Работа с периферией---------------------
  // Следующие две команды должны предшествовать всему коду
  setCPUarchitecture(CPU_ARCHITECTURE.arm64);
  setCustomLibrary('/app/libperiphery_arm64.so');

  // Статус светодиода, изначально выключен
  bool statusLed = false;
  // Выход, подключение светодиода, индикации наличия писем
  final gpioLed = int.parse(Platform.environment['GPIO_LED'] ?? '');
  final GPIO gpioOut = GPIO(gpioLed, GPIOdirection.gpioDirOut);

  gpioOut.write(false);

  ReceivePort mainInputPort = ReceivePort();

  await Isolate.spawn(callbackFunction, mainInputPort.sendPort);

  // Получаем сообщения из изолята
  mainInputPort.listen((_) {
    // Кнопка нажата, нам не важно передаваемое значение
    if (statusLed) {
      statusLed = false;
      gpioOut.write(false);
    }
  });

  //-----------------Получаем информацию о письмах-----------------
  final config = await Discover.discover(email, isLogEnabled: false);
  if (config == null) {
    return;
  }

  final account = MailAccount.fromDiscoveredSettings('my account', email, emailPassword, config);

  final mailClient = MailClient(account, isLogEnabled: false);
  try {
    await mailClient.connect();
    await mailClient.selectInbox(); // Выбираем папку "ВХОДЯЩИЕ"
    final messages = await mailClient.fetchMessages(count: 100);
    // print('Количество писем в почтовом ящике ${messages.length}');
    for (final msg in messages) {
      senderEmail = msg.fromEmail;
      nameEmail = exp.firstMatch(msg.from.toString())?.group(1);
      deliveryDate = msg.decodeDate();

      resultTransaction = await dbRepository.checkAndSaveEmail(senderEmail, nameEmail, deliveryDate);
      if (resultTransaction) {
        statusLed = true;
        gpioOut.write(true);
      }
    }

    // Если запущен startPolling, здесь будет информация о новых email
    mailClient.eventBus.on<MailLoadEvent>().listen((event) async {
      senderEmail = event.message.fromEmail;
      nameEmail = exp.firstMatch(event.message.from.toString())?.group(1);
      deliveryDate = event.message.decodeDate();

      resultTransaction = await dbRepository.checkAndSaveEmail(senderEmail, nameEmail, deliveryDate);
      if (resultTransaction) {
        statusLed = true;
        gpioOut.write(true);
      }
    });

    // Запускаем опрос email каждые 2 минуты
    await mailClient.startPolling();
  } on MailException catch (e) {
    print('High level API failed with $e');
  }
}

//-----------------Изолят для работы с кнопкой-----------------
// Точка входа изолята, функция верхнего уровня
void callbackFunction(SendPort mainSendPort) {
  // Так как изолят не разделяет память дублируем следующие две команды
  setCPUarchitecture(CPU_ARCHITECTURE.arm64);
  setCustomLibrary('/app/libperiphery_arm64.so');

  // Вход, подключение кнопки для выключение светодиода
  final gpioButton = int.parse(Platform.environment['GPIO_BUTTON'] ?? '');
  final GPIO gpioIn = GPIO(gpioButton, GPIOdirection.gpioDirIn);
  gpioIn.setGPIOedge(GPIOedge.gpioEdgeFalling);

  while (true) {
    // Ожидание прерывания
    GPIOreadEvent event = gpioIn.readEvent();
    if (GPIOedge.gpioEdgeFalling == event.edge) {
      mainSendPort.send(true);
    }
  }
}
