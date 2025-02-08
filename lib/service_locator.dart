import 'package:customlabs_backend/modules/root/root_controller.dart';
import 'package:customlabs_backend/modules/user/user_controller.dart';
import 'package:customlabs_backend/services/database_service.dart';
import 'package:customlabs_backend/services/environment_service.dart';
import 'package:get_it/get_it.dart';
import 'services/firebase_service.dart';
import 'modules/user/user_repository.dart';

final locator = GetIt.instance;

void setupServiceLocator() {
  // Register services as lazy singletons
  locator.registerLazySingleton(() => EnvService());
  locator.registerLazySingleton(() => DatabaseService());
  locator.registerLazySingleton(() => FirebaseService(locator.get<EnvService>()));

  // Register controllers as lazy singletons
  locator.registerLazySingleton(() => RootController());
  locator.registerLazySingleton(() => UserController());

  // Register UserRepository as a singleton
  locator.registerSingleton<UserRepository>(UserRepository(locator.get<DatabaseService>()));
} 