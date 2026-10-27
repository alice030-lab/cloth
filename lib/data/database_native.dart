import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';

Future<Database> openDatabase() async {
  final dir = await getApplicationSupportDirectory();
  return databaseFactoryIo.openDatabase(p.join(dir.path, 'outfit_canvas.db'));
}
