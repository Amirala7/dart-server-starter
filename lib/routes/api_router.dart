import 'package:customlabs_backend/modules/root/root_controller.dart';
import 'package:customlabs_backend/modules/user/user_controller.dart';
import 'package:customlabs_backend/services/environment_service.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf/shelf.dart';
import 'package:customlabs_backend/service_locator.dart';

class ApiRouter {
  static final ApiRouter _instance = ApiRouter._internal();
  final Router _router = Router();
  final _envService = locator<EnvService>();
  
  // Factory constructor
  factory ApiRouter() {
    return _instance;
  }

  // Private constructor
  ApiRouter._internal() {
    _setupRoutes();
  }

  // Getter for the router
  Router get router => _router;

  void _setupRoutes() {
    final rootController = locator<RootController>();
    final userController = locator<UserController>();

    // Define routes
    _router.get('/', rootController.get);

    // User routes
    _router.post('/user', userController.createUser); // Create user
    _router.get('/user', userController.getUser); // Get user
    _router.patch('/user', userController.updateUser); // Update user
    _router.delete('/user', userController.deleteUser); // Delete user
    
    // Development only routes
    if (_envService.get('ENVIRONMENT') != 'production') {
      _router.get('/dev/token', userController.generateTestToken);
    }
    
    // Catch all handler for unhandled routes
    _router.all('/<ignored|.*>', (Request request) => 
      Response.notFound('Route not found'));
  }
} 