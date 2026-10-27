import 'package:sembast_web/sembast_web.dart';

Future<Database> openDatabase() =>
    databaseFactoryWeb.openDatabase('outfit_canvas_v1');
